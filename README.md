# Migrate Google Authenticator OTPs to 1Password on macOS

Bulk-import Google Authenticator accounts into 1Password by taking screenshots
of the export QR codes and processing them locally on a Mac.

> [!WARNING]
> The screenshots contain live OTP secrets. Run this only on a trusted Mac,
> never upload or commit the screenshots, and delete them after verification.
> See [SECURITY.md](SECURITY.md).

## The Simple Flow

1. Export all accounts from Google Authenticator.
2. Take one screenshot of every export QR-code page.
3. Put the screenshots in one folder on the Mac.
4. Preview the accounts that will be created:

   ```bash
   ./otpauth-bulk-import.sh \
     --vault "Private" \
     --qr-folder ~/Desktop/ga-export
   ```

5. If the preview is correct, import them:

   ```bash
   ./otpauth-bulk-import.sh \
     --vault "Private" \
     --qr-folder ~/Desktop/ga-export \
     --apply
   ```

The importer creates one new 1Password Login item per OTP and tags it
`google-authenticator-import`. It does not modify existing Login items.

After importing, verify the OTP codes, merge them into existing Login items
where appropriate, and only then remove the originals from Google
Authenticator.

## One-Time Setup

### Requirements

- macOS
- The device containing the Google Authenticator accounts
- 1Password for Mac and [1Password CLI](https://developer.1password.com/docs/cli/)
- Node.js, any recent supported version
- `jq`:

  ```bash
  brew install jq
  ```

- Xcode Command Line Tools, which provide Swift for local QR decoding:

  ```bash
  xcode-select --install
  ```

- The appropriate macOS binary from the
  [dim13/otpauth releases page](https://github.com/dim13/otpauth/releases)

### Install `otpauth`

Run `uname -m` to determine the Mac architecture:

- `arm64`: download the `darwin-arm64` asset.
- `x86_64`: download the `darwin-amd64` asset.

The latest release verified on June 11, 2026 is `v0.6.0`. After downloading the
correct archive:

```bash
case "$(uname -m)" in
  arm64) OTPAUTH_ASSET="otpauth-v0.6.0-darwin-arm64.tgz" ;;
  x86_64) OTPAUTH_ASSET="otpauth-v0.6.0-darwin-amd64.tgz" ;;
  *) printf 'Unsupported architecture: %s\n' "$(uname -m)" >&2; exit 1 ;;
esac

mkdir -p /tmp/otpauth-install
tar -xzf "$HOME/Downloads/$OTPAUTH_ASSET" -C /tmp/otpauth-install
sudo install -d -m 0755 /usr/local/otpauth
sudo install -m 0755 /tmp/otpauth-install/otpauth /usr/local/otpauth/otpauth
sudo install -m 0755 ./otpauth.sh /usr/local/bin/otpauth.sh
```

Confirm it works:

```bash
otpauth.sh -h
```

### Activate 1Password CLI

In 1Password, open **Settings > Developer** and enable
**Integrate with 1Password CLI**.

Keep the 1Password desktop app unlocked, then verify CLI access:

```bash
op signin
op whoami
```

## Run the Migration

### 1. Export and Screenshot

1. In Google Authenticator, open **Transfer accounts** or
   **Transfer codes**.
2. Select **Export accounts** and select all accounts.
3. Google Authenticator may show several sequential QR-code pages.
4. Take exactly one screenshot of every page.
5. Transfer the screenshots into a dedicated folder, for example:

   ```text
   ~/Desktop/ga-export/
     export-01.png
     export-02.png
     export-03.png
   ```

The folder decoder supports HEIC, JPEG, PNG, and TIFF. It uses Apple's local
Vision framework and does not upload the images. Duplicate QR screenshots cause
an error.

### 2. Preview

From this repository, run:

```bash
./otpauth-bulk-import.sh \
  --vault "Private" \
  --qr-folder ~/Desktop/ga-export
```

Confirm:

- The batch count matches the number of QR screenshots.
- The account count matches Google Authenticator.
- The displayed account names and usernames look correct.

No 1Password items are created during preview.

### 3. Import

When the preview is correct:

```bash
./otpauth-bulk-import.sh \
  --vault "Private" \
  --qr-folder ~/Desktop/ga-export \
  --apply
```

If an error interrupts the import, inspect the items already tagged
`google-authenticator-import` before retrying. The importer is not resumable,
and a complete retry can create duplicates.

### 4. Verify and Clean Up

1. Compare codes from 1Password and Google Authenticator.
2. Test sign-in to every critical account using 1Password.
3. Verify 1Password sync and OTP generation on another authorized device.
4. Merge imported OTP fields into existing Login items where appropriate.
5. Keep Google Authenticator unchanged until verification is complete.
6. Delete the screenshot folder and empty Trash.

## Important Security Notes

- Each Google Authenticator export QR code contains OTP secrets for multiple
  accounts. Anyone who obtains it can generate valid codes.
- During preview and import, the upstream `otpauth` tool receives each
  migration link as a command-line argument. It may briefly be visible to
  other processes running as the same macOS user.
- Storing a site's password and OTP seed together in 1Password improves
  usability but removes separation between the two factors if the vault is
  compromised.
- Do not save the batch migration link as the password of a Login item.
- Recovery codes should be stored securely before removing Google
  Authenticator entries.

## Manual Alternative

To process one migration link manually instead of importing a screenshot
folder:

```bash
otpauth.sh --prompt-http
```

Paste the `otpauth-migration://` link at the hidden prompt, then open
[http://localhost:6060/](http://localhost:6060/) and add each displayed OTP to
1Password.

The bulk importer can also accept migration links at hidden prompts:

```bash
./otpauth-bulk-import.sh --vault "Private"
```

Press Return at an empty prompt after the final batch. Add `--apply` only after
reviewing the preview.

## Rollback

Before Google Authenticator is removed or reset, rollback is immediate: keep
using its existing OTP entries.

If an imported OTP is incorrect:

1. Use Google Authenticator or a recovery code to sign in.
2. Remove the incorrect OTP field or imported Login item from 1Password.
3. Export and import that account again.
4. Verify two consecutive codes and complete a real sign-in.

After Google Authenticator has been removed, recovery requires service recovery
codes or the service's account-recovery process.

## References

- [dim13/otpauth](https://github.com/dim13/otpauth)
- [Use 1Password as an authenticator](https://support.1password.com/one-time-passwords/)
- [Google Authenticator help](https://support.google.com/accounts/answer/1066447)
