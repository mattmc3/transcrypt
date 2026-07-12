# Suite-wide fixture: generate the shared gpg test keyring exactly once.
# Keys are read-mostly, so every file and test can share it, including
# under `bats --jobs N`.

source "${BASH_SOURCE[0]%/*}/_gpg_helper.bash"

setup_suite() {
  # short path: gpg daemon sockets live in GNUPGHOME and unix socket
  # paths are limited to ~104 chars on macOS; BATS tmpdirs are too deep
  GNUPGHOME=$(mktemp -d /tmp/tc-gpg.XXXXXX)
  export GNUPGHOME
  chmod 700 "$GNUPGHOME"
  for uid in "Alice Test <$ALICE>" "Bob Test <$BOB>" "Charlie Test <$CHARLIE>"; do
    gpg --batch --pinentry-mode loopback --passphrase '' \
      --quick-gen-key "$uid" default default never
  done

  # a key that expired long ago, generated in the past via faked time
  gpg --batch --pinentry-mode loopback --passphrase '' \
    --faked-system-time '20200101T000000!' \
    --quick-gen-key "Expired Test <$EXPIRED>" default default 20200201T000000

  # canonical fingerprints, for asserting normalized recipient storage
  export ALICE_FPR BOB_FPR CHARLIE_FPR EXPIRED_FPR
  ALICE_FPR=$(fpr_of "$ALICE")
  BOB_FPR=$(fpr_of "$BOB")
  CHARLIE_FPR=$(fpr_of "$CHARLIE")
  EXPIRED_FPR=$(fpr_of "$EXPIRED")
}

teardown_suite() {
  gpgconf --kill all 2>/dev/null || true
  rm -rf "$GNUPGHOME"
}
