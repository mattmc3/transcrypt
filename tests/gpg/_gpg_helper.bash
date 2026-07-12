# Helper for the gpg backend test suite. Reuses the main test helper but
# initializes transcrypt with the gpg format and an ephemeral keyring.
#
# Unlike the v2/v3 suites, each test here builds its git repo in the
# test-unique $BATS_TEST_TMPDIR, so the suite is safe under `bats --jobs N`.

source "$BATS_TEST_DIRNAME/../_test_helper.bash"

TRANSCRYPT="$BATS_TEST_DIRNAME/../../transcrypt"

# shellcheck disable=SC2034  # used by test files and setup_suite.bash
ALICE='alice@example.com'
BOB='bob@example.com'
CHARLIE='charlie@example.com'

# The shared keyring is generated once for the whole suite; see
# setup_suite.bash

function init_transcrypt_gpg {
  "$TRANSCRYPT" --format=gpg \
    --gpg-recipient="$ALICE" --gpg-recipient="$BOB" --yes
}

function setup {
  TEST_REPO="$BATS_TEST_TMPDIR/repo"
  git init --quiet -b main "$TEST_REPO"
  pushd "$TEST_REPO" >/dev/null || exit 1
  # Tests will fail if name and email aren't set
  git config --local user.name "John Doe"
  git config --local user.email johndoe@example.com
  if [[ ! "${SETUP_SKIP_INIT_TRANSCRYPT:-}" ]]; then
    init_transcrypt_gpg
  fi
}

function teardown {
  # repo cleanup is bats's job: everything lives in $BATS_TEST_TMPDIR
  popd >/dev/null || exit 1
}

# Count how many gpg public keys a ciphertext is encrypted to
function recipient_count {
  gpg --list-packets --list-only 2>/dev/null | grep -c 'pubkey enc packet'
}
