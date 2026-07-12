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
