#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/_gpg_helper.bash"

@test "init: gpg format init succeeds with recipients and no password" {
  # setup already ran init_transcrypt_gpg; verify the result
  run git config --get --local filter.crypt.clean
  [ "$status" -eq 0 ]
  [[ "$output" = *"clean context=default"* ]]

  run git config --get --local filter.crypt.smudge
  [ "$status" -eq 0 ]
  [[ "$output" = *"smudge context=default"* ]]

  # no password is stored for the gpg format
  run git config --get --local transcrypt.password
  [ "$status" -ne 0 ]
}

@test "init: recipients are stored normalized to full fingerprints" {
  # init used email identifiers; stored config must be canonical fprs
  run git config --get-all --local transcrypt.gpg-recipient
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$ALICE_FPR" ]
  [ "${lines[1]}" = "$BOB_FPR" ]
}

@test "init: accepts key ids and fingerprints as recipients" {
  uninstall_transcrypt
  bob_keyid="${BOB_FPR: -16}"
  run "$TRANSCRYPT" --format=gpg \
    --gpg-recipient="$ALICE_FPR" --gpg-recipient="$bob_keyid" --yes
  [ "$status" -eq 0 ]

  run git config --get-all --local transcrypt.gpg-recipient
  [ "${lines[0]}" = "$ALICE_FPR" ]
  [ "${lines[1]}" = "$BOB_FPR" ]
}

@test "init: missing recipients on repo with ciphertext lists key ids" {
  encrypt_named_file sensitive_file "my secret"
  uninstall_transcrypt
  # simulate a fresh clone: no filters configured, working tree holds the
  # committed ciphertext (uninstall left decrypted files, so restore)
  git reset --hard --quiet

  run "$TRANSCRYPT" --format=gpg --yes
  [ "$status" -ne 0 ]
  [[ "$output" = *"encrypted to"* ]]
  # hint must include the keyid of at least one existing recipient
  keyid=$(git show HEAD:sensitive_file | keyids_of | head -1)
  [[ "$output" = *"$keyid"* ]]
}

@test "init: gpg format recorded in local git config, no settings file" {
  run git config --get --local transcrypt.format
  [ "$status" -eq 0 ]
  [ "$output" = "gpg" ]

  # gpg backend has no shared crypto parameters, so no .transcrypt/ dir
  [ ! -e .transcrypt ]
}

@test "init: display shows gpg format and recipients" {
  run $TRANSCRYPT --display
  [ "$status" -eq 0 ]
  [[ "$output" = *"FORMAT:   gpg"* ]]
  [[ "$output" = *"$ALICE"* ]]
  [[ "$output" = *"$BOB"* ]]
}

@test "init: gpg format without recipients fails" {
  uninstall_transcrypt
  run $TRANSCRYPT --format=gpg --yes
  [ "$status" -ne 0 ]
  [[ "$output" = *"recipient"* ]]
}

@test "init: unknown recipient fails" {
  uninstall_transcrypt
  run $TRANSCRYPT --format=gpg --gpg-recipient=nobody@example.com --yes
  [ "$status" -ne 0 ]
}

@test "init: interactive gpg configure shows recipients, not password prompts" {
  uninstall_transcrypt
  run bash -c "printf 'y\n' | $TRANSCRYPT --format=gpg --gpg-recipient=$ALICE"
  [ "$status" -eq 0 ]
  [[ "$output" = *"FORMAT:   gpg"* ]]
  [[ "$output" = *"$ALICE_FPR"* ]]
  [[ "$output" != *"PASSWORD"* ]]
  [[ "$output" != *"Generate a random password"* ]]
}

@test "init: expired recipient key is rejected" {
  uninstall_transcrypt
  run $TRANSCRYPT --format=gpg --gpg-recipient="$EXPIRED" --yes
  [ "$status" -ne 0 ]
  [[ "$output" = *"not usable"* ]]
}

@test "init: uninstall leaves decrypted file in working copy" {
  encrypt_named_file sensitive_file "my secret"

  run $TRANSCRYPT --uninstall --yes
  [ "$status" -eq 0 ]

  run cat sensitive_file
  [ "${lines[0]}" = "my secret" ]
}
