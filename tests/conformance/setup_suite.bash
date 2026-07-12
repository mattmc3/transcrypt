# Suite-wide fixture for the conformance suite. gpg needs a keyring;
# generate it once per run at a socket-safe short path (gpg daemon
# sockets live in GNUPGHOME; macOS caps unix socket paths around 104
# chars, and BATS tmpdirs are too deep).

source "${BASH_SOURCE[0]%/*}/_conformance_helper.bash"

setup_suite() {
  if [[ $FORMAT_UNDER_TEST == 'gpg' ]]; then
    GNUPGHOME=$(mktemp -d /tmp/tc-conf.XXXXXX)
    export GNUPGHOME
    chmod 700 "$GNUPGHOME"
    local uid
    for uid in "Alice Test <$ALICE>" "Bob Test <$BOB>"; do
      gpg --batch --pinentry-mode loopback --passphrase '' \
        --quick-gen-key "$uid" default default never
    done
  fi
}

teardown_suite() {
  if [[ $FORMAT_UNDER_TEST == 'gpg' ]]; then
    gpgconf --kill all 2>/dev/null || true
    rm -rf "$GNUPGHOME"
  fi
}
