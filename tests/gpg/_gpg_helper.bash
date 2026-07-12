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

# Full fingerprint of a key, looked up by any gpg identifier
function fpr_of {
  gpg --list-keys --with-colons -- "$1" 2>/dev/null |
    awk -F: '/^fpr/ {print $10; exit}'
}

# Scratch GNUPGHOMEs live at socket-safe short paths in /tmp, so they
# cannot be inside BATS_TEST_TMPDIR. Register each one; teardown cleans
# them (and their agents) even when the test fails mid-way.
function register_scratch_gnupghome {
  echo "$1" >> "$BATS_TEST_TMPDIR/scratch-gnupghomes"
}

function make_empty_gnupghome {
  local home
  home=$(mktemp -d /tmp/tc-empty.XXXXXX)
  chmod 700 "$home"
  register_scratch_gnupghome "$home"
  echo "$home"
}

# GNUPGHOME containing only public keys
function make_pubkey_only_home {
  local home
  home=$(mktemp -d /tmp/tc-pub.XXXXXX)
  chmod 700 "$home"
  register_scratch_gnupghome "$home"
  gpg --export --armor -- "$ALICE" "$BOB" |
    GNUPGHOME=$home gpg --batch --quiet --import 2>/dev/null
  echo "$home"
}

function teardown {
  if [[ -f "$BATS_TEST_TMPDIR/scratch-gnupghomes" ]]; then
    local home
    while IFS= read -r home; do
      [[ -d $home ]] || continue
      GNUPGHOME=$home gpgconf --kill all 2>/dev/null || true
      rm -rf "$home"
    done < "$BATS_TEST_TMPDIR/scratch-gnupghomes"
  fi
  popd >/dev/null || exit 1
}
