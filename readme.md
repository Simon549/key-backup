# Description
Small and dirty shell script that exports a pgp-key from your `gpg` key-ring and creates a PDF for printing and offline storage.
The output contains some key metadata, that is automatically gathered, and an ASCII representation of the key. 
Furthermore, it contains mulitple QR codes, that provide easier assembly from a printed document.
The tool can also automatically create and back up the revocation certificate in the same way.
Both the key export (and the revocation) are exported via gpg's `--armored --symmetric` flags. 
Therefore, the export is encrypted with an additional password.

# Dependencies
- GNU Privacy Guard (gpg); Version >= 2.4.4
- coreutils
- python3
- python3-venv
- pdflatex with the following packages:
    - geometry
    - graphicx
    - fancyhdr
    - moreverb
    - pgffor

# Synopsis
```
./keybackup.sh <keyid> [-r|--revocation] [-n|--filename <filename>] [-h|--hint <hint>] [-s|--qrsize <size>] [-f|--font <path>]
```

The script does currently not support an export of the entire key-ring.

Parameters:
- `keyid`: The long key-id of the root-key that can be retrieved via: `gpg --list-keys --keyid-format=long`.
  WATCH OUT: Export only works on root keys. Exporting only one single subkey is not directly possible. When a key
  is exported all subkeys are automatically exported with it. If you just need the subkeys exported (usually for transfer
  to another daily use machine), do not use this script at all - it is only for long term offline storage.
- `--revocation`: Also generates a revocation certificate for the key. It will be protected with the same 
  passphrase as the key (optional).
- `--filename`: The name of the key-file the key should be exported to (optional; otherwise it will be `keybackup`).
- `--hint`: A hint for the symmetric encryption (optional).
- `--qrsize`: Chunk size for the QR codes. (optional; otherwise it will be `512`)
  WATCH OUT: Large QR codes (with bad print quality) could be hard to scan.
  WATCH OUT: (Very) Small QR codes could be broken, as the inscribed number leads to too much data loss.
- `--font`: Path to a true-type font (optional)
  If not provided, the QR codes do not have inscribed numbers. 
  The script was tested (and produces nicely scanable outputs) with the following fonts:
    - **Ubuntu-B.ttf**: Usually (on ubuntu systems) in `/usr/share/fonts/truetype/ubuntu/Ubuntu-B.ttf`

The script calls gpg in the background and handles most things. 
However you will be interactively prompted: 
- to unlock your key for export
- to provide a passphrase for the symmetric key encryption
- to provide a passphrase for the symmetric revocation certificate encryption
- to state a reason and detailed message for the revocation certificate creation

# Usage 
**WATCH OUT:** There is no guarantee on a compromised machine, that files are not copied for the short time window, that they 
exist. To mitigate risk run the offline part while deactivating all external connections.
**NEVER RUN THIS (OR EVEN IMPORT YOUR (ROOT) KEY) ON UNTRUSTED MACHINES.**

## Online 
1. Set up the needed python environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   deactivate
   ```
2. Watch out that all dependencies are installed!
3. Read the instructions below. Make sure you understand everything.
4. Get a second device with internet access in case you need to look something up.
5. Disconnect all external connections.

## Offline
0. MAKE SURE YOU ARE OFFLINE!
1. Ensure that you have (admin) smartcard access.
2. Import the root key. 
3. Create the keys and the revocation certificates.
4. Handle keys:
   - All used keys should go to smartcards (e.g. YubiKeys) immediately. They should NOT be backed up. 
   - Create seperate backup keys for offline storage.
   - Initialize services like `pass` with all keys that should be used with them (smartcard + backup keys).
5. Export the backup keys (and revocation certificates).
6. For each key that should be backed up run the bash script:
    ```bash
    chmod +x createBackup.sh
    ./keybackup.sh KEYID -r -n keyname -h "Password hint" -s 512 -f "/path/to/truetype/font"
    ```
7. All files are created and bundled into the output directory. Everything non relevant else is removed.
8. Copy the zip directory to secure external storage devices.
9. Check if the keys can be imported without errors (as well as revocation)
   ```bash
   GNUPGHOME=$(mktemp -d)
   gpg --homedir "$GNUPGHOME" --decrypt keyname.asc | gpg --homedir "$GNUPGHOME" --import
   gpg --homedir "$GNUPGHOME" --list-secret-keys --fingerprint
   gpg --homedir "$GNUPGHOME" --decrypt keyname.rev.asc | gpg --homedir "$GNUPGHOME" --import
   gpg --homedir "$GNUPGHOME" --list-keys 
   rm -rf "$GNUPGHOME"
   ```
   In case the shell closed/crashed before the `rm`: search and delete the directory under `echo $TMPDIR` (probably in `\tmp`)
10. Print the PDF to be better guarded against bitrot and defect storage devices.
    - Make sure that QR codes can actually be scanned (high enough print resolution).
    - Use good paper (archival/acid-free).
    - Use waterproof storage. Watch out with laminating the paper as this can trap moisture.
    - Use fireproof storage if possible.
    - Store paper in a secure, cool and dry place.
11. Check if the QR codes can be scanned and assembled correctly
    1. Assemble into the file as described in the pdf
    2. Compare hashes. Hash can be generated with:
    ```bash
    sha256sum keyfile.asc
    ```
11. Remove the backup keys (private part at least) from the GPG keyring. 
12. Make sure the root key is backed up properly (check all electronic storage systems, check all printed versions).
13. Remove the root key.
14. Make sure all electronical storage devices are unplugged and stored safely.
15. Make sure to clean the recycling bin to not leak keys.
16. Now you can go back online again.

IN CASE OF ERROR:
Clean up, but make sure to not accidentally delete old keys and lock yourself out completely.
Do not go online unless you checked the last 5 points.

# Tipps
For the offline portion if no internet is available, here are some useful commands.

## Pass
- Reinitialize pass with the new keys (pass asks to re-encrypt everything to new key - select yes):
  ```bash
  pass init KEYID-SMARTCARD1 KEYID-SMARTCARD2 KEYID-BACKUP
  ```

## GPG
- Listing keys (with ID):
  ```bash
  gpg --list-keys --fingerprint --keyid-format=long
  gpg --list-secret-keys --fingerprint --keyid-format=long
  ```
- Importing (root) key:
  ```bash
  gpg --decrypt keyname.asc | gpg --import
  ```
- Export key: 
  ```bash
  gpg --export-secret-keys --armor ROOTKEYID | gpg --symmetric --armor -o keyname.asc
  ```
  WATCH OUT: `--armored` only provides an ASCII representation, `--symmetric` actually encrypts a key
  WATCH OUT: This exports the root-key and all subkeys. While this is great for backups, it should not be imported 
  on machines for daily use. Export just the subkeys here instead.
- Export subkeys only:
  ```bash
  gpg --export-secret-subkeys --armor ROOTKEYID | gpg --symmetric --armor -o keyname.asc
  ```
- Delete keys (in case both public and private should be deleted, delete the private one first):
  ```bash
  gpg --delete-secret-key KEYID
  gpg --delete-key KEYID
  ```
- Generate root key:
  ```bash
  gpg --expert --full-generate-key
  ```
  Select `RSA (set your own capabilities)` or `ECC (set your own capabilities)` and then select/deselect everything, 
  so that you have a certify only key
  Select key length (for RSA) and algorithm (for ECC) and set your name, email and give the key a name.
  Set the expiry and choose a strong passphrase (this encrypts all of your other keys that are subkeys of this one).
  WATCH OUT: It is best practise to immediately generate the revocation certificate afterwards. Either do it manually, 
  or use the `keybackup` script with the `-r|--revocation` flag.
- Generate sub key:
  ```bash
  gpg --edit-key ROOTKEYID
  gpg> addkey
  # if you want this key to be moved to a smartcard, best do it now immediately
  gpg> save
  ```
  Select key length (for RSA) and algorithm (for ECC) and set your name, email and give the key a name.
  Best to set trust for the key on the machine afterwards.
- Move a subkey to a smartcard:
  WATCH OUT: The key will be moved (not copied) and can never be moved back from the smartcard.
  WATCH OUT: Do not move the root key to the smartcard. It should only be stored offline.
  ```bash
  gpg --edit-key ROOTKEYID
  gpg> key 1 # select the correct subkey 
  gpg> keytocard
  gpg> save
  ```
- Setting trust for a key:
  ```bash
  gpg --edit-key ROOTKEYID
  gpg> trust
  ```
  Set to 5 ('Trust ultimately') if it is your key and you do not want gpg from complaining on key usage.
  If you have bigger key-setups and you want to export/import trust from machine to machine:
  ```bash
  gpg --export-ownertrust > ownertrust.txt
  gpg --import-ownertrust < ownertrust.txt
  ```
  WATCH OUT: While leaking this file does not put your keys cryptographically at risk, it does expose your key 
  setup and hierarchy.
- Revocation certificate creation:
  ```bash
  gpg --output revoke.asc --gen-revoke ROOTKEYID
  ```

