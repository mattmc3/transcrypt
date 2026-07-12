# transcrypt gpg format

The gpg format encrypts files to the public keys of one or more gpg
recipients instead of deriving a symmetric key from a shared password.
The working tree holds plaintext at natural paths; every commit holds
PGP-armored ciphertext.

## Quick start

```sh
cd <your-repo>
transcrypt --format=gpg \
  --gpg-recipient=662E63E410C1AF41 \
  --gpg-recipient=1A6B4E9FC96C1D2B --yes

transcrypt --add '*.secret'   # or edit .gitattributes directly
git add .gitattributes your.secret
git commit -m 'Add encrypted secret'
```

`--gpg-recipient` accepts anything gpg can resolve to exactly one key:
a key id, a full fingerprint, or an email address. Whatever you pass,
transcrypt stores the key's full fingerprint in git config; ambiguous
identifiers (an email matching two keys) are rejected.

A fresh clone needs the recipient public keys in the gpg keyring, then
the same configure command with the recipients again (recipient config
is clone-local, not committed):

```sh
transcrypt --format=gpg --gpg-recipient=<keyid> ... --yes
```

Forgot who the recipients are? Run it without `--gpg-recipient` and the
error lists the key ids the existing files are encrypted to.

Decrypting requires a private key for any one recipient. Encrypting
needs only public keys, but the clean filter decrypts the committed
version to detect changes; on a machine with no secret key, `git add`
still works but re-encrypts the file every time (a warning explains
this), so expect noisy diffs there.

## Configuration

Everything lives in local git config, set at configure time. There is
no shared password and no `.transcrypt/` settings file; PGP ciphertext
is self-describing, so clones need no committed crypto parameters.

| Setting | Meaning |
|---|---|
| `transcrypt.format` | `gpg` selects this format |
| `transcrypt.gpg-recipient` | multi-valued; one full key fingerprint per entry |
| `transcrypt.gnupghome` | optional alternate `GNUPGHOME` for all gpg calls |

Manage recipients with git config, then rekey:

```sh
git config --add transcrypt.gpg-recipient 3E5C4D8F662E63E410C1AF41...
git config --unset transcrypt.gpg-recipient <old-fingerprint>
transcrypt --rekey --yes
```

Any gpg identifier works in `--add` (rekey normalizes entries to full
fingerprints), but `--unset` matches the stored value, so pass the
fingerprint shown by `git config --get-all transcrypt.gpg-recipient`
or `transcrypt --display`.

## How the clean filter stays stable

GPG output is not deterministic (random session key and prefix), which
would normally make every file look perpetually modified to git. The
clean filter is idempotent instead: it decrypts the ciphertext already
staged in the index and, when that matches the incoming plaintext
byte-for-byte, re-emits the existing ciphertext unchanged. Only a real
content change (or `--rekey`) produces fresh encryption.

Consequences:

- Reverting a file to previously committed content produces new
  ciphertext (the old blob is only reused while it is in the index).
- Recipient changes do not re-encrypt files by themselves; run
  `transcrypt --rekey --yes` after changing recipients.
- A machine holding only public keys can clone and read ciphertext but
  cannot `git add` encrypted files.

## Not supported (yet)

- `--upgrade` on a gpg-format repository
- Multiple contexts (`--context=NAME`) with the gpg format
- Interactive (non `--yes`) configuration flow shows password prompts
  that do not apply to this format

## Removing a recipient is not revocation

A removed recipient could decrypt every ciphertext they already saw.
`--rekey` protects future commits only. If a key is compromised or a
person leaves, rotate the secrets themselves.
