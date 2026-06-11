# Security

## Sensitive data handled by this project

Google Authenticator migration QR codes and `otpauth-migration://` links contain
the OTP secrets for every account in an export batch. Individual `otpauth://`
URLs also contain OTP secrets.

Anyone who obtains these values can generate valid one-time passwords.

## Safe usage

- Run the scripts only on a trusted Mac.
- Keep the 1Password desktop app and CLI integration secured.
- Do not upload QR screenshots or migration URLs to online decoding services.
- Disable clipboard-history, screen-sharing, and screen-recording tools during
  migration.
- Treat process-list access by the same macOS user as a possible exposure. The
  upstream `otpauth` tool receives migration links as command-line arguments.
- Verify every imported OTP before removing it from Google Authenticator.
- Delete export screenshots and other temporary migration material after
  verification.
- Do not commit real QR exports, migration links, `otpauth://` URLs, or OTP
  secrets to this repository.

## Reporting a vulnerability

Report security issues privately to the repository maintainer. Do not include
real OTP secrets, migration links, QR screenshots, recovery codes, or account
credentials in a report.
