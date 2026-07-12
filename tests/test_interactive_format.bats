#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/_test_helper.bash"

# Interactive configuration on an unconfigured repository must offer the
# format choice before format-specific prompts. (Fork addition; not part
# of the upstream suite.)

function setup {
  init_git_repo
}

@test "interactive: bare run asks for the format before the cipher" {
  run bash -c "printf '\n\ny\ny\n' | $TRANSCRYPT"
  [[ "$output" = *"Encrypt using which format?"* ]]
  [[ "$output" = *"openssl"* ]]
  [[ "$output" = *"Encrypt using which cipher?"* ]]
}

@test "interactive: empty answer defaults to the openssl format" {
  run bash -c "printf '\n\ny\ny\n' | $TRANSCRYPT"
  [ "$status" -eq 0 ]
  # openssl stores no transcrypt.format key
  run git config --get --local transcrypt.format
  [ "$status" -ne 0 ]
  run git config --get --local transcrypt.cipher
  [ "$output" = "aes-256-cbc" ]
}

@test "interactive: --format flag skips the format prompt" {
  run bash -c "printf '\ny\ny\n' | $TRANSCRYPT --format=pbkdf2"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Encrypt using which format?"* ]]
  run git config --get --local transcrypt.format
  [ "$output" = "pbkdf2" ]
}

@test "interactive: choosing gpg prompts for recipients" {
  # keyring with one usable key, at a socket-safe short path
  GNUPGHOME=$(mktemp -d /tmp/tc-int.XXXXXX)
  export GNUPGHOME
  chmod 700 "$GNUPGHOME"
  gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-gen-key 'Ivy Test <ivy@example.com>' default default never

  run bash -c "printf 'gpg\nivy@example.com\n\ny\n' | $TRANSCRYPT"
  gpgconf --kill all 2>/dev/null || true
  status_saved=$status
  output_saved=$output
  rm -rf "$GNUPGHOME"
  [ "$status_saved" -eq 0 ]
  [[ "$output_saved" = *"Add recipient"* ]]

  run git config --get --local transcrypt.format
  [ "$output" = "gpg" ]
  run git config --get-all --local transcrypt.gpg-recipient
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "interactive: unknown format answer fails with the known list" {
  run bash -c "printf 'rot13\n' | $TRANSCRYPT"
  [ "$status" -ne 0 ]
  [[ "$output" = *"unsupported format"* ]]
  [[ "$output" = *"pbkdf2"* ]]
}
