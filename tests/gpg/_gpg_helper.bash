# Helper for the gpg backend test suite. Reuses the main test helper but
# initializes transcrypt with the gpg format and an ephemeral keyring.

source "$BATS_TEST_DIRNAME/../_test_helper.bash"

ALICE='alice@example.com'
BOB='bob@example.com'
CHARLIE='charlie@example.com'

# One throwaway keyring per test file; keys are read-mostly so tests share it
function setup_file {
  export GNUPGHOME="$BATS_FILE_TMPDIR/gnupg"
  mkdir -p "$GNUPGHOME"
  chmod 700 "$GNUPGHOME"
  for uid in "Alice Test <$ALICE>" "Bob Test <$BOB>" "Charlie Test <$CHARLIE>"; do
    gpg --batch --pinentry-mode loopback --passphrase '' \
      --quick-gen-key "$uid" default default never
  done
}

function teardown_file {
  gpgconf --kill all 2>/dev/null || true
}

function init_transcrypt_gpg {
  "$BATS_TEST_DIRNAME"/../../transcrypt --format=gpg \
    --gpg-recipient="$ALICE" --gpg-recipient="$BOB" --yes
}

function setup {
  pushd "$BATS_TEST_DIRNAME" || exit 1
  init_git_repo
  if [[ ! "$SETUP_SKIP_INIT_TRANSCRYPT" ]]; then
    init_transcrypt_gpg
  fi
}

# Count how many gpg public keys a ciphertext is encrypted to
function recipient_count {
  gpg --list-packets --list-only 2>/dev/null | grep -c 'pubkey enc packet'
}
