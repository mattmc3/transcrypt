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

## Validating a repository: --check

`transcrypt --check` verifies that every encrypted file in the index is
valid ciphertext, and reports the health of every configured recipient
key (expired, revoked, disabled, expiring within 30 days, or absent
from the keyring). It needs no keys and no prior configuration, so a CI
job can run it to catch corrupted or plaintext-staged secrets from
collaborators who never installed the pre-commit hook:

```sh
./transcrypt --check
```

The pre-commit hook performs the same ciphertext validation on every
commit; PGP armor carries a checksum, so a hand-edited or corrupted
secret is detected even on machines that hold no key.

## Safety behavior worth knowing

- Merging: if a secret cannot be decrypted (no secret key), the merge
  driver aborts rather than merging raw ciphertext and re-encrypting
  the garbage. Resolve such merges on a machine with a secret key.
- Rekeying: a file that cannot be decrypted fails the rekey loudly
  instead of silently keeping the old recipient list.
- Expired keys cannot cause data loss. Expiry blocks *encryption* only;
  decryption works forever with the secret key. If every recipient key
  expires, the repo is temporarily read-only until a key is renewed
  (`gpg --quick-set-expire <fpr> 2y`) or replaced, then rekeyed.
- Real data loss requires losing every recipient *secret key*. Guard
  against it with a dedicated recovery keypair: keep its secret key
  offline and add its fingerprint as a standing recipient.
- `transcrypt --add` marks gpg patterns `-text` so eol conversion
  (`core.autocrlf`) never touches armored ciphertext or restored
  plaintext; secret files round-trip byte-exact.

## Not supported with the gpg format

These refuse with an error rather than half-working: `--upgrade`,
`--flush-credentials` (no local credentials exist), contexts
(`--context=NAME`), and `--export-gpg` / `--import-gpg` (no password to
carry).

## Removing a recipient is not revocation

A removed recipient could decrypt every ciphertext they already saw.
`--rekey` protects future commits only. If a key is compromised or a
person leaves, rotate the secrets themselves.
