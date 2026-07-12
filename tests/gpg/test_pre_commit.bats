#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/_gpg_helper.bash"

@test "pre-commit: pre-commit hook installed on init" {
  [ -f .git/hooks/pre-commit-crypt ]
  [ -f .git/hooks/pre-commit ]
}

@test "pre-commit: permit commit of encrypted file with encrypted content" {
  echo "Secret stuff" > sensitive_file
  encrypt_named_file sensitive_file

  echo " and more secrets" >> sensitive_file
  git add sensitive_file
  run git commit -m "Added more"
  [ "$status" -eq 0 ]
}

@test "pre-commit: reject commit of hand-corrupted ciphertext" {
  echo "Secret stuff" > sensitive_file
  encrypt_named_file sensitive_file

  # simulate a hand-edit: header intact, one body byte changed (breaks
  # the armor CRC), staged without the clean filter as a raw editor would
  git show HEAD:sensitive_file | corrupt_armor > sensitive_file
  echo "" > .gitattributes
  git add sensitive_file
  echo "sensitive_file filter=crypt diff=crypt merge=crypt" > .gitattributes

  run git commit -m "corrupted"
  [ "$status" -ne 0 ]
  [[ "$output" = *"not valid"* ]]
}

@test "check: --check passes a healthy repo and fails a corrupted one" {
  echo "Secret stuff" > sensitive_file
  encrypt_named_file sensitive_file

  run $TRANSCRYPT --check
  [ "$status" -eq 0 ]

  # commit a corrupted blob, bypassing the clean filter and the hook,
  # the way a collaborator without transcrypt configured would
  git show HEAD:sensitive_file | corrupt_armor > sensitive_file
  echo "" > .gitattributes
  git add sensitive_file
  git commit -m "corrupted" --no-verify
  echo "sensitive_file filter=crypt diff=crypt merge=crypt" > .gitattributes

  run $TRANSCRYPT --check
  [ "$status" -ne 0 ]
  [[ "$output" = *"sensitive_file"* ]]
}

@test "check: --check reports expired recipient keys" {
  echo "Secret stuff" > sensitive_file
  encrypt_named_file sensitive_file

  git config --add transcrypt.gpg-recipient "$EXPIRED_FPR"

  run $TRANSCRYPT --check
  [ "$status" -ne 0 ]
  [[ "$output" = *"EXPIRED"* ]]
  [[ "$output" = *"$EXPIRED_FPR"* ]]
}

@test "check: --check tolerates recipients missing from the keyring" {
  echo "Secret stuff" > sensitive_file
  encrypt_named_file sensitive_file

  # CI-like machine: no keys at all; ciphertext validation still works
  # and unknown key health must not fail the check
  emptyhome=$(make_empty_gnupghome)
  git config --local transcrypt.gnupghome "$emptyhome"

  run $TRANSCRYPT --check
  [ "$status" -eq 0 ]
  [[ "$output" = *"not in this keyring"* ]]
}

@test "pre-commit: reject commit of encrypted file with unencrypted content" {
  echo "Secret stuff" > sensitive_file
  encrypt_named_file sensitive_file

  echo " and more secrets" >> sensitive_file

  # Disable file's crypt config in .gitattributes, add change, then re-enable
  echo "" > .gitattributes
  git add sensitive_file
  echo "sensitive_file filter=crypt diff=crypt merge=crypt" > .gitattributes

  run git commit -m "Added more"
  [ "$status" -ne 0 ]
  [[ "${output}" = *"Transcrypt managed file is not encrypted in the Git index: sensitive_file"* ]]
}
