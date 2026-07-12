# Backend-agnostic conformance suite helper. The same tests run against
# every crypto format; select one per run:
#
#     TRANSCRYPT_TEST_FORMAT=openssl bats tests/conformance/
#     TRANSCRYPT_TEST_FORMAT=gpg     bats tests/conformance/
#     TRANSCRYPT_TEST_FORMAT=pbkdf2  bats tests/conformance/

source "$BATS_TEST_DIRNAME/../_test_helper.bash"

# this suite lives one directory deeper than the main one
TRANSCRYPT="$BATS_TEST_DIRNAME/../../transcrypt"

FORMAT_UNDER_TEST="${TRANSCRYPT_TEST_FORMAT:-openssl}"
export ALICE='alice@example.com'
export BOB='bob@example.com'

function init_transcrypt_for_format {
  case $FORMAT_UNDER_TEST in
  openssl)
    "$TRANSCRYPT" --cipher=aes-256-cbc --password='abc 123' --yes
    ;;
  gpg)
    "$TRANSCRYPT" --format=gpg \
      --gpg-recipient="$ALICE" --gpg-recipient="$BOB" --yes
    ;;
  pbkdf2)
    "$TRANSCRYPT" --format=pbkdf2 --password='abc 123' --yes
    ;;
  *)
    echo "unknown TRANSCRYPT_TEST_FORMAT: $FORMAT_UNDER_TEST" >&2
    exit 1
    ;;
  esac
}

function setup {
  init_git_repo
  init_transcrypt_for_format
}
