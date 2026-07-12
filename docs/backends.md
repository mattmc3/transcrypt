# Crypto backends

A crypto format named `NAME` is a set of bash functions named
`crypt_NAME_*` inside the `transcrypt` script. Shared machinery only
calls hooks through the `crypt_call` dispatcher, so adding a format
means writing functions, never threading if/then branches through
shared code. Register the name in `CRYPT_BACKENDS` so unconfigured
validation (`--check` in CI) recognizes the format's ciphertext.

## Format selection

Filter commands written by `configure` carry an explicit `format=NAME`
argument (the same mechanism as `context=`), so the per-file hot path
never reads git config. Absence of the argument means `openssl`, which
keeps repositories configured by upstream transcrypt working unchanged.
Cold paths (configure, display, pre-commit, --check) read the
`transcrypt.format` git config key, which `save_configuration` writes
for every format except `openssl`.

## Required hooks

| Hook | Contract |
|---|---|
| `clean FILENAME TEMPFILE` | stdin is cached in TEMPFILE; write ciphertext to stdout. Must be idempotent: unchanged plaintext must produce byte-identical output (deterministic encryption, or reuse of the index blob as the gpg backend does) |
| `smudge TEMPFILE` | ciphertext cached in TEMPFILE; write plaintext to stdout, falling back to `cat` when decryption is impossible so keyless clones are non-destructive |
| `textconv FILENAME` | decrypt the named file to stdout, same fallback |
| `is_ciphertext FILE` | cheap magic-bytes probe of the named file |
| `validate_blob` | read a blob on stdin; return 0 when it is valid ciphertext. Used by the pre-commit hook and `--check`; prefer a keyless structural check |
| `configure` | collect and validate the format's settings (interactively or from flags) and normalize them into variables `save_config` will persist |
| `confirm` | print the pending settings section of the interactive confirmation prompt |
| `save_config` | persist the format's settings to local git config |
| `display` | print the configured settings for `--display` |

## Optional hooks

Absence of an optional hook makes `crypt_call` refuse the operation
with a uniform "not supported with the NAME format" error, so a format
opts into operations by defining them and never needs guard clauses:

| Hook | Used by |
|---|---|
| `flush_credentials` | `--flush-credentials` (capability marker) |
| `upgrade_creds` | `--upgrade` (capability marker) |
| `export_creds`, `import_creds` | `--export-gpg`, `--import-gpg` (capability markers) |
| `rekey_prepare` | called before re-staging files on `--rekey` (eg: gpg exports a flag that forces fresh encryption) |
| `merge_check_sides BASE LOCAL REMOTE PATH` | abort a merge when smudge could not decrypt a side, instead of merging raw ciphertext |
| `blob_prefix_matches BLOB` | distinguishes corrupted ciphertext from plaintext in pre-commit error messages |
| `extra_attrs` | extra .gitattributes attributes for `--add` patterns (eg: gpg adds `-text`) |
| `health` | recipient/credential health report for `--check` |

## The pbkdf2 socket

The intended third backend is `pbkdf2`: upstream's stalled v3 effort
(PR #126) specifies it — `openssl enc -pbkdf2 -iter N` with a salt
derived from a shared base-salt, so ciphertext stays deterministic.
Unlike gpg, it needs public parameters (kdf, iterations, base-salt)
shared by every clone before first decrypt; the backend owns that
storage decision (likely a committed settings file). Nothing in the
shared machinery assumes otherwise.
