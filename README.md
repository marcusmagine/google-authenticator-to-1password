# Migrate Google Authenticator OTPs to 1Password on macOS

> [!WARNING]
> This project handles live OTP secrets. Run it only on a trusted Mac, never
> commit or upload export QR screenshots, and delete temporary export material
> after verification. See [SECURITY.md](SECURITY.md).

## Purpose

Use this runbook to copy all one-time password (OTP) entries from Google
Authenticator to 1Password while keeping a working rollback path.

The migration does not change the OTP secret registered with each service. It
copies that secret into 1Password. Google Authenticator should remain unchanged
until every migrated entry has been tested.

## Security notes

- A Google Authenticator `otpauth-migration://` link contains the OTP secrets
  for every account in that export batch. Anyone who obtains it can generate
  valid OTP codes.
- Use a trusted, offline QR-code reader. Do not upload the export QR code to a
  website or cloud-based decoder.
- Disable or pause clipboard-history tools before copying migration links.
- Do not paste a migration link directly into a shell command because it will
  be saved in shell history.
- Do not save a batch migration link as the password of every Login item. It
  duplicates all exported OTP secrets across multiple items. The rollback path
  is to retain Google Authenticator until verification is complete.
- Storing a site's password and OTP seed together in 1Password improves
  usability but removes the separation between those two factors if the vault
  is compromised. Confirm that this matches your security policy.

## Prerequisites

- The device containing the working Google Authenticator entries
- 1Password for Mac, unlocked and synchronized
- 1Password CLI installed and desktop-app integration enabled
- Node.js, any recent supported version
- `jq` (`brew install jq`)
- Xcode Command Line Tools (`xcode-select --install`) when using
  `--qr-folder`; this provides Swift for the local QR decoder
- A trusted QR-code reader on macOS that can extract a QR code's text
- Administrator access on the Mac for installation under `/usr/local`
- The latest appropriate macOS binary from the
  [dim13/otpauth releases page](https://github.com/dim13/otpauth/releases)
- Recovery codes or another recovery method for critical accounts

## Install `otpauth`

Review the downloaded release and select the asset matching the Mac's CPU
architecture. Run `uname -m`: use the `darwin-arm64` asset for `arm64`, or the
`darwin-amd64` asset for `x86_64` Intel Macs.

The latest release verified on June 11, 2026 is `v0.6.0`. Set the asset name
before extracting it:

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

Confirm that the wrapper works:

```bash
otpauth.sh -h
```

## Migration procedure

### Optional: bulk-create all OTP entries

For a large migration, `otpauth-bulk-import.sh` can decode multiple Google
Authenticator export batches and create one new tagged Login item per OTP. It
does not update or match existing Login items automatically, because export
labels are not guaranteed to identify the correct existing item.

Make the scripts executable:

```bash
chmod +x ./otpauth-bulk-import.sh ./otpauth-to-1password-json.js ./decode-qr-folder.swift
```

Enable the 1Password CLI integration in **1Password > Settings > Developer**.
Turn on **Integrate with 1Password CLI**, then verify the CLI can authenticate:

```bash
op signin
op whoami
```

The 1Password desktop app must be unlocked when the bulk importer runs.

Run a preview first:

```bash
./otpauth-bulk-import.sh --vault "Private"
```

Paste each extracted `otpauth-migration://` link at the hidden prompt. Press
Return at an empty prompt after the final batch. The preview prints only titles
and usernames.

Alternatively, capture every Google Authenticator export QR page as a separate
screenshot and place the images in one dedicated folder. Supported formats are
HEIC, JPEG, PNG, and TIFF. Then decode and preview the entire folder locally:

```bash
chmod +x ./decode-qr-folder.swift
./otpauth-bulk-import.sh --vault "Private" --qr-folder ~/Desktop/ga-export
```

The folder mode uses Apple's built-in Vision framework. It does not upload the
images. Duplicate QR screenshots cause an error. Confirm that the reported
batch count matches the number of export QR pages and that the item count
matches the Google Authenticator inventory.

During both preview and import, the upstream `otpauth` tool receives each
migration link as a command-line argument. The link may therefore be visible
briefly to other processes running as the same user. Run the migration only on
a trusted Mac.

When the preview is correct, create the items:

```bash
./otpauth-bulk-import.sh --vault "Private" --qr-folder ~/Desktop/ga-export --apply
```

The new items are tagged `google-authenticator-import`. Review them, merge OTP
fields into existing Login items where appropriate, and verify the codes before
removing Google Authenticator entries.

If authentication or another error interrupts an `--apply` run, inspect the
tagged items already created before retrying. The importer is not resumable and
a complete retry can create duplicate items.

### 1. Prepare and inventory

1. Update Google Authenticator and 1Password.
2. Confirm macOS date and time are set automatically.
3. Record the number and names of entries in Google Authenticator.
4. Confirm recovery access for critical accounts before migrating them.
5. Pause clipboard-history tools and close screen-sharing or recording apps.

### 2. Export a batch from Google Authenticator

1. In Google Authenticator, open **Transfer accounts** or **Transfer codes**.
2. Select **Export accounts**.
3. Select the accounts and generate the export QR codes.
4. Capture every export QR page exactly once. Store the screenshots in a
   dedicated local folder, or scan each QR code with a trusted offline reader.
5. If scanning manually, copy the extracted text. It must start with:

   ```text
   otpauth-migration://offline?data=
   ```

Google Authenticator may generate multiple QR codes when exporting many
accounts. Process each QR code as a separate batch.

### 3. Decode and display individual QR codes

Start the local-only HTTP server. The wrapper will prompt for the migration
link without displaying it or storing it in shell history:

```bash
otpauth.sh --prompt-http
```

The upstream tool receives the link as a command-line argument, so it may be
visible briefly to other processes running as the same user. Perform the
migration only on a trusted Mac.

Open [http://localhost:6060/](http://localhost:6060/) in a browser. Do not
replace `localhost` with a LAN address.

### 4. Add each OTP to 1Password

For each QR code shown by the local server:

1. Find or create the correct Login item in 1Password.
2. Select **Edit**.
3. Select **Add More**, then **One-Time Password**.
4. Select the QR-code icon and scan the QR code from the screen or clipboard.
5. Save the Login item.
6. Compare the current code in 1Password with Google Authenticator. Wait for
   the next code and compare again.
7. Mark the entry as migrated in the inventory.

Do not store the migration link as a password. If policy requires an encrypted
backup, store one copy as a separate restricted Secure Note, clearly label it
as containing all OTP seeds in the batch, and delete it after final
verification.

### 5. Finish each batch

1. Confirm the number and names of decoded entries match the exported batch.
2. Stop the local server with `Control-C`.
3. Clear the clipboard:

   ```bash
   printf '' | pbcopy
   ```

4. Repeat steps 2 through 5 for every remaining export QR code.

### 6. Verify before cutover

1. Confirm every inventory entry exists in 1Password.
2. Sign in to every critical account using the OTP generated by 1Password.
3. Verify 1Password sync and OTP generation on a second authorized device.
4. Keep Google Authenticator unchanged for an agreed observation period.

## Rollback

Before Google Authenticator is removed or reset, rollback is immediate: use its
existing OTP entries.

If a 1Password OTP is incorrect:

1. Use Google Authenticator or a recovery code to sign in.
2. Remove the incorrect One-Time Password field from the 1Password item.
3. Export and migrate that Google Authenticator entry again.
4. Verify two consecutive codes and complete a real sign-in.

After Google Authenticator has been removed, recovery requires the service's
recovery codes or account-recovery process. A saved migration link can recreate
the old OTP seeds, but it is a high-impact secret and is not the preferred
rollback mechanism.

## Completion and cleanup

Only after all entries have been verified:

1. Confirm recovery codes are stored securely.
2. Delete any temporary screenshots, QR images, migration links, and restricted
   migration backup notes.
3. Empty Trash if temporary files were created.
4. Re-enable clipboard history only after confirming the migration link is not
   present.
5. Remove Google Authenticator entries only when the observation period and
   rollback requirements are satisfied.

## References

- [dim13/otpauth](https://github.com/dim13/otpauth)
- [Use 1Password as an authenticator](https://support.1password.com/one-time-passwords/)
- [Google Authenticator help](https://support.google.com/accounts/answer/1066447)
