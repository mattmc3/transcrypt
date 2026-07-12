# transcrypt gpg format

The gpg format encrypts files to the public keys of one or more gpg
recipients instead of deriving a symmetric key from a shared password.
The working tree holds plaintext at natural paths; every commit holds
PGP-armored ciphertext.

## Quick start

```sh
cd <your-repo>
transcrypt --format=gpg \
  --gpg-recipient=you@example.com \
  --gpg-recipient=teammate@example.com --yes

transcrypt --add '*.secret'   # or edit .gitattributes directly
git add .gitattributes your.secret
git commit -m 'Add encrypted secret'
```

A fresh clone needs the recipient public keys in the gpg keyring, then:

```sh
transcrypt --format=gpg --yes
```

Decrypting requires a private key for any one recipient; encrypting
(and therefore `git add`) requires one too, because the clean filter
decrypts the committed version to detect changes.

## Configuration

Everything lives in local git config, set at configure time. There is
no shared password and no `.transcrypt/` settings file; PGP ciphertext
is self-describing, so clones need no committed crypto parameters.

| Setting | Meaning |
|---|---|
| `transcrypt.format` | `gpg` selects this format |
| `transcrypt.gpg-recipient` | multi-valued; one entry per recipient key |
| `transcrypt.gnupghome` | optional alternate `GNUPGHOME` for all gpg calls |

Manage recipients with git config, then rekey:

```sh
git config --add transcrypt.gpg-recipient new@example.com
git config --unset transcrypt.gpg-recipient old@example.com
transcrypt --rekey --yes
```

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
