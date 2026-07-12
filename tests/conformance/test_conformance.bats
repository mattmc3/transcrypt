#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/_conformance_helper.bash"

SECRET_CONTENT="My secret content"

@test "conformance($TRANSCRYPT_TEST_FORMAT): working copy is plaintext, git is ciphertext" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]

  run git show HEAD:sensitive_file --no-textconv
  [ "$status" -eq 0 ]
  [ "${lines[0]}" != "$SECRET_CONTENT" ]
}

@test "conformance($TRANSCRYPT_TEST_FORMAT): textconv decrypts" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  run git show HEAD:sensitive_file --textconv
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]
}

@test "conformance($TRANSCRYPT_TEST_FORMAT): unchanged file stays clean across touch and re-add" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  blob_before=$(git rev-parse HEAD:sensitive_file)

  touch sensitive_file
  git add sensitive_file

  run check_repo_is_clean
  [ "$status" -eq 0 ]

  blob_after=$(git rev-parse :0:sensitive_file)
  [ "$blob_before" = "$blob_after" ]
}

@test "conformance($TRANSCRYPT_TEST_FORMAT): checkout round-trips problematic bytes" {
  FILENAME="problem bytes file.txt"
  printf '\375 \0 shh' > "$FILENAME"
  encrypt_named_file "$FILENAME"

  cp "$FILENAME" "$BATS_TEST_TMPDIR/original"
  rm "$FILENAME"
  git checkout --force -- "$FILENAME"
  run cmp "$FILENAME" "$BATS_TEST_TMPDIR/original"
  [ "$status" -eq 0 ]
}

@test "conformance($TRANSCRYPT_TEST_FORMAT): empty file is stored empty" {
  touch empty_file
  encrypt_named_file empty_file

  run git show HEAD:empty_file --no-textconv
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "conformance($TRANSCRYPT_TEST_FORMAT): pre-commit rejects plaintext staged around the filter" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  echo "more secrets" >> sensitive_file
  echo "" > .gitattributes
  git add sensitive_file
  echo "sensitive_file filter=crypt diff=crypt merge=crypt" > .gitattributes

  run git commit -m "should fail"
  [ "$status" -ne 0 ]
  [[ "$output" = *"not encrypted in the Git index"* ]]
}

@test "conformance($TRANSCRYPT_TEST_FORMAT): --check passes a healthy repo" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  run $TRANSCRYPT --check
  [ "$status" -eq 0 ]
}

@test "conformance($TRANSCRYPT_TEST_FORMAT): --list shows the encrypted file" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  run $TRANSCRYPT --list
  [ "$status" -eq 0 ]
  [[ "$output" = *"sensitive_file"* ]]
}

@test "conformance($TRANSCRYPT_TEST_FORMAT): uninstall leaves plaintext, reset restores ciphertext" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  run $TRANSCRYPT --uninstall --yes
  [ "$status" -eq 0 ]

  run cat sensitive_file
  [ "${lines[0]}" = "$SECRET_CONTENT" ]

  git reset --hard --quiet
  run cat sensitive_file
  [ "${lines[0]}" != "$SECRET_CONTENT" ]
}

@test "conformance($TRANSCRYPT_TEST_FORMAT): non-conflicting merge succeeds in plaintext" {
  echo "1. First step" > sensitive_file
  encrypt_named_file sensitive_file

  git checkout -b branch-2
  echo "2. Second step" >> sensitive_file
  git add sensitive_file
  git commit -m "Add line 2"

  git checkout -
  git merge branch-2

  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "1. First step" ]
  [ "${lines[1]}" = "2. Second step" ]
}
