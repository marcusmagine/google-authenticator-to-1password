#!/usr/bin/env bash

set -euo pipefail

readonly OTPAUTH_BIN="/usr/local/otpauth/otpauth"

if [[ ! -x "${OTPAUTH_BIN}" ]]; then
  printf 'Error: %s is missing or not executable.\n' "${OTPAUTH_BIN}" >&2
  exit 1
fi

if [[ "${1:-}" == "--prompt-http" ]]; then
  if (( $# != 1 )); then
    printf 'Usage: %s --prompt-http\n' "${0##*/}" >&2
    exit 2
  fi

  printf 'Migration link: ' >&2
  IFS= read -r -s migration_link
  printf '\n' >&2

  if [[ "${migration_link}" != otpauth-migration://offline\?data=* ]]; then
    printf 'Error: input is not a Google Authenticator migration link.\n' >&2
    exit 2
  fi

  exec "${OTPAUTH_BIN}" -http=localhost:6060 -link "${migration_link}"
fi

exec "${OTPAUTH_BIN}" "$@"
