#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly JSON_HELPER="${SCRIPT_DIR}/otpauth-to-1password-json.js"
readonly QR_DECODER="${SCRIPT_DIR}/decode-qr-folder.swift"
readonly OTPAUTH_BIN="${OTPAUTH_BIN:-/usr/local/otpauth/otpauth}"
readonly IMPORT_TAG="google-authenticator-import"

apply=false
vault=""
qr_folder=""

usage() {
  cat <<'EOF'
Usage: otpauth-bulk-import.sh --vault VAULT [--qr-folder FOLDER] [--apply]

Preview imported OTP entries by default. Add --apply to create tagged Login
items in 1Password. With --qr-folder, decode all Google Authenticator export QR
screenshots in that folder. The script never updates existing items automatically.
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --apply)
      apply=true
      shift
      ;;
    --vault)
      vault="${2:-}"
      shift 2
      ;;
    --qr-folder)
      qr_folder="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Error: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${vault}" ]]; then
  printf 'Error: --vault is required.\n' >&2
  exit 2
fi

for dependency in "${OTPAUTH_BIN}" "${JSON_HELPER}"; do
  if [[ ! -x "${dependency}" ]]; then
    printf 'Error: %s is missing or not executable.\n' "${dependency}" >&2
    exit 1
  fi
done

for command_name in node jq op; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    printf 'Error: required command is missing: %s\n' "${command_name}" >&2
    exit 1
  fi
done

if [[ -n "${qr_folder}" ]]; then
  if [[ ! -x "${QR_DECODER}" ]]; then
    printf 'Error: %s is missing or not executable.\n' "${QR_DECODER}" >&2
    exit 1
  fi
  if ! command -v swift >/dev/null 2>&1; then
    printf 'Error: required command is missing: swift\n' >&2
    exit 1
  fi
fi

if [[ "${apply}" == true ]]; then
  op signin >/dev/null
  printf 'Creating new Login items in vault "%s".\n' "${vault}" >&2
else
  printf 'Preview only. No 1Password items will be created.\n' >&2
fi

batch=0
total=0

process_migration_link() {
  local migration_link="$1"
  local decoded metadata title username otp_url

  if [[ "${migration_link}" != otpauth-migration://offline\?data=* ]]; then
    printf 'Error: input is not a Google Authenticator migration link.\n' >&2
    exit 2
  fi

  batch=$((batch + 1))
  decoded="$("${OTPAUTH_BIN}" -link "${migration_link}")"
  unset migration_link

  while IFS= read -r otp_url; do
    [[ -n "${otp_url}" ]] || continue
    metadata="$(printf '%s' "${otp_url}" | node "${JSON_HELPER}" metadata)"
    title="$(printf '%s' "${metadata}" | jq -r '.title')"
    username="$(printf '%s' "${metadata}" | jq -r '.username')"
    total=$((total + 1))

    if [[ "${apply}" == true ]]; then
      printf '%s' "${otp_url}" |
        IMPORT_TAG="${IMPORT_TAG}" node "${JSON_HELPER}" |
        op item create --vault "${vault}" - >/dev/null
      printf 'Created: %s [%s]\n' "${title}" "${username}"
    else
      printf 'Would create: %s [%s]\n' "${title}" "${username}"
    fi
  done <<< "${decoded}"

  unset decoded
}

if [[ -n "${qr_folder}" ]]; then
  migration_links="$("${QR_DECODER}" "${qr_folder}")"
  while IFS= read -r migration_link; do
    [[ -n "${migration_link}" ]] || continue
    process_migration_link "${migration_link}"
  done <<< "${migration_links}"
  unset migration_links migration_link
else
  while true; do
    printf 'Migration link for batch %d, or press Return to finish: ' "$((batch + 1))" >&2
    IFS= read -r -s migration_link
    printf '\n' >&2

    if [[ -z "${migration_link}" ]]; then
      break
    fi

    process_migration_link "${migration_link}"
    unset migration_link
  done
fi

printf '%s %d item(s) from %d batch(es). Tag: %s\n' \
  "$([[ "${apply}" == true ]] && printf 'Created' || printf 'Previewed')" \
  "${total}" "${batch}" "${IMPORT_TAG}"
