#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/../_test_helper.bash"

# this suite lives one directory deeper than the main one
TRANSCRYPT="$BATS_TEST_DIRNAME/../../transcrypt"

SECRET_CONTENT="My secret content"

function init_transcrypt_pbkdf2 {
  "$TRANSCRYPT" --format=pbkdf2 --password='abc 123' --yes
}

function setup {
  init_git_repo
  if [[ ! "${SETUP_SKIP_INIT_TRANSCRYPT:-}" ]]; then
    init_transcrypt_pbkdf2
  fi
}

@test "pbkdf2: init records format, default iterations, and a base salt" {
  run git config --get --local transcrypt.format
  [ "$output" = "pbkdf2" ]

  run git config --get --local transcrypt.iterations
  [ "$status" -eq 0 ]
  [ "$output" -ge 210000 ]

  run git config --get --local transcrypt.base-salt
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  # filter commands carry the format argument
  run git config --get --local filter.crypt.clean
  [[ "$output" = *"format=pbkdf2"* ]]
}

@test "pbkdf2: encryption produces no deprecated key derivation warning" {
  echo "$SECRET_CONTENT" > sensitive_file
  echo 'sensitive_file filter=crypt diff=crypt merge=crypt' >> .gitattributes
  run git add .gitattributes sensitive_file
  [ "$status" -eq 0 ]
  [[ "$output" != *"deprecated key derivation"* ]]
}

@test "pbkdf2: ciphertext uses the Salted__ container" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  run git show HEAD:sensitive_file --no-textconv
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == U2FsdGVk* ]]
}

@test "pbkdf2: custom --iterations is honored" {
  uninstall_transcrypt
  run "$TRANSCRYPT" --format=pbkdf2 --password='abc 123' --iterations=300000 --yes
  [ "$status" -eq 0 ]
  run git config --get --local transcrypt.iterations
  [ "$output" = "300000" ]
}

@test "pbkdf2: display shows parameters and a full onboarding command" {
  run $TRANSCRYPT --display
  [ "$status" -eq 0 ]
  [[ "$output" = *"FORMAT:     pbkdf2"* ]]
  [[ "$output" = *"ITERATIONS:"* ]]
  [[ "$output" = *"BASE-SALT:"* ]]
  [[ "$output" = *"--format=pbkdf2"* ]]
  [[ "$output" = *"--iterations="* ]]
  [[ "$output" = *"--base-salt="* ]]
}

@test "pbkdf2: a clone configured with the displayed parameters decrypts" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  iterations=$(git config --get --local transcrypt.iterations)
  base_salt=$(git config --get --local transcrypt.base-salt)

  # simulate a fresh clone: unconfigure and restore raw ciphertext
  "$TRANSCRYPT" --uninstall --yes
  git reset --hard --quiet

  run "$TRANSCRYPT" --format=pbkdf2 --password='abc 123' \
    --iterations="$iterations" --base-salt="$base_salt" --yes
  [ "$status" -eq 0 ]

  run cat sensitive_file
  [ "${lines[0]}" = "$SECRET_CONTENT" ]
}

@test "pbkdf2: rekey to a new password re-encrypts" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  blob_before=$(git rev-parse HEAD:sensitive_file)

  run "$TRANSCRYPT" --rekey --password='new pass' --yes
  [ "$status" -eq 0 ]

  blob_after=$(git rev-parse :0:sensitive_file)
  [ "$blob_before" != "$blob_after" ]

  run cat sensitive_file
  [ "${lines[0]}" = "$SECRET_CONTENT" ]
}

@test "pbkdf2: --upgrade and --export-gpg refuse" {
  run $TRANSCRYPT --upgrade --yes
  [ "$status" -ne 0 ]
  [[ "$output" = *"not supported with the pbkdf2 format"* ]]

  run $TRANSCRYPT --export-gpg=nobody --yes
  [ "$status" -ne 0 ]
  [[ "$output" = *"not supported with the pbkdf2 format"* ]]
}
