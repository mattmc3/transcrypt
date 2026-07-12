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

@test "init: recipients are stored as multi-valued git config" {
  run git config --get-all --local transcrypt.gpg-recipient
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$ALICE" ]
  [ "${lines[1]}" = "$BOB" ]
}

@test "init: gpg format recorded in local git config, no settings file" {
  run git config --get --local transcrypt.format
  [ "$status" -eq 0 ]
  [ "$output" = "gpg" ]

  # gpg backend has no shared crypto parameters, so no .transcrypt/ dir
  [ ! -e .transcrypt ]
}

@test "init: display shows gpg format and recipients" {
  run ../../transcrypt --display
  [ "$status" -eq 0 ]
  [[ "$output" = *"FORMAT:   gpg"* ]]
  [[ "$output" = *"$ALICE"* ]]
  [[ "$output" = *"$BOB"* ]]
}

@test "init: gpg format without recipients fails" {
  uninstall_transcrypt
  run ../../transcrypt --format=gpg --yes
  [ "$status" -ne 0 ]
  [[ "$output" = *"recipient"* ]]
}

@test "init: unknown recipient fails" {
  uninstall_transcrypt
  run ../../transcrypt --format=gpg --gpg-recipient=nobody@example.com --yes
  [ "$status" -ne 0 ]
}

@test "init: uninstall leaves decrypted file in working copy" {
  encrypt_named_file sensitive_file "my secret"

  run ../../transcrypt --uninstall --yes
  [ "$status" -eq 0 ]

  run cat sensitive_file
  [ "${lines[0]}" = "my secret" ]
}
