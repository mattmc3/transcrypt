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

## The pbkdf2 backend

`pbkdf2` is the openssl format with a modern KDF: `openssl enc -pbkdf2
-iter N -md sha512` instead of the legacy single-round EVP_BytesToKey,
finishing what upstream's stalled v3 effort (PR #126) started. The
per-file salt stays deterministic (HMAC over the plaintext, keyed with
filename, password, and a per-project base-salt), so clean idempotence
comes from determinism as in the openssl format.

Its parameters (iterations, base-salt) live in local git config like
every other format's settings: decryption never needs the base-salt
(OpenSSL embeds each file's salt in the Salted__ header), and the
parameters travel out-of-band with the password via the `--display`
copy-paste line. No committed settings file; mismatched parameters
fail loudly (decrypt falls back to ciphertext) rather than corrupting
anything.

## Conformance suite

Backend-agnostic behavior is verified per format by the parameterized
suite in `tests/conformance/`:

    TRANSCRYPT_TEST_FORMAT=openssl bats tests/conformance/
    TRANSCRYPT_TEST_FORMAT=gpg     bats tests/conformance/
    TRANSCRYPT_TEST_FORMAT=pbkdf2  bats tests/conformance/

CI runs it once per format. A new backend must pass the conformance
suite; its own test directory then covers only format-specific
behavior (as `tests/gpg/` and `tests/pbkdf2/` do).
