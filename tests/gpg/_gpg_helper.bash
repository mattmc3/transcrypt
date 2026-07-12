# Helper for the gpg backend test suite. Reuses the main test helper but
# initializes transcrypt with the gpg format instead of a password.
# The shared test keyring is generated once in setup_suite.bash.

source "$BATS_TEST_DIRNAME/../_test_helper.bash"

# used by test files and setup_suite.bash
export ALICE='alice@example.com'
export BOB='bob@example.com'
export CHARLIE='charlie@example.com'

function init_transcrypt_gpg {
  "$TRANSCRYPT" --format=gpg \
    --gpg-recipient="$ALICE" --gpg-recipient="$BOB" --yes
}

function setup {
  init_git_repo
  if [[ ! "${SETUP_SKIP_INIT_TRANSCRYPT:-}" ]]; then
    init_transcrypt_gpg
  fi
}

# Count how many gpg public keys a ciphertext is encrypted to
function recipient_count {
  gpg --list-packets --list-only 2>/dev/null | grep -c 'pubkey enc packet'
}
