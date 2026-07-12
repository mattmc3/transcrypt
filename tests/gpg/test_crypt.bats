#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/_gpg_helper.bash"

SECRET_CONTENT="My secret content"
PGP_HEADER="-----BEGIN PGP MESSAGE-----"

@test "crypt: encrypted file is decrypted in working copy" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]
}

@test "crypt: file is PGP armored in git" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  run git show HEAD:sensitive_file --no-textconv
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$PGP_HEADER" ]
}

@test "crypt: git show --textconv decrypts" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  run git show HEAD:sensitive_file --textconv
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]
}

@test "crypt: ciphertext is encrypted to every recipient" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  count=$(git show HEAD:sensitive_file --no-textconv | recipient_count)
  [ "$count" -eq 2 ]
}

@test "crypt: unchanged file stays clean across touch and re-add" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  blob_before=$(git rev-parse HEAD:sensitive_file)

  touch sensitive_file
  git add sensitive_file

  run check_repo_is_clean
  [ "$status" -eq 0 ]

  # idempotent clean reused the committed ciphertext byte-for-byte
  blob_after=$(git rev-parse :0:sensitive_file)
  [ "$blob_before" = "$blob_after" ]
}

@test "crypt: changed content produces a new ciphertext blob" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  blob_before=$(git rev-parse HEAD:sensitive_file)

  echo "changed secret" > sensitive_file
  git add sensitive_file

  run check_repo_is_clean
  [ "$status" -ne 0 ]

  blob_after=$(git rev-parse :0:sensitive_file)
  [ "$blob_before" != "$blob_after" ]

  git commit -m 'Change secret'
  run git show HEAD:sensitive_file --textconv
  [ "${lines[0]}" = "changed secret" ]
}

@test "crypt: clean passes already-encrypted input through unchanged" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  git show HEAD:sensitive_file --no-textconv > /tmp/ciphertext.$$
  run bash -c "$TRANSCRYPT clean context=default sensitive_file < /tmp/ciphertext.$$"
  rm -f /tmp/ciphertext.$$
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$PGP_HEADER" ]
}

@test "crypt: smudge falls back to ciphertext when no key can decrypt" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  emptyhome=$(make_empty_gnupghome)
  run bash -c "git show HEAD:sensitive_file --no-textconv |
    GNUPGHOME='$emptyhome' $TRANSCRYPT smudge context=default"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$PGP_HEADER" ]
}

@test "crypt: transcrypt.gnupghome config is honored over environment" {
  git config --local transcrypt.gnupghome "$GNUPGHOME"
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  # strip GNUPGHOME and point HOME at an empty dir; only the git config
  # can lead gpg to the right keyring
  run env -u GNUPGHOME HOME="$BATS_TEST_TMPDIR" git show HEAD:sensitive_file --textconv
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]
}

@test "crypt: rekey encrypts to added recipient" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  git config --add transcrypt.gpg-recipient "$CHARLIE"
  run $TRANSCRYPT --rekey --yes
  [ "$status" -eq 0 ]

  count=$(git show :0:sensitive_file --no-textconv | recipient_count)
  [ "$count" -eq 3 ]

  # plaintext unchanged after rekey
  run cat sensitive_file
  [ "${lines[0]}" = "$SECRET_CONTENT" ]

  # the manually added email was normalized to a fingerprint by rekey
  run git config --get-all --local transcrypt.gpg-recipient
  [ "${lines[0]}" = "$ALICE_FPR" ]
  [ "${lines[1]}" = "$BOB_FPR" ]
  [ "${lines[2]}" = "$CHARLIE_FPR" ]
}

@test "crypt: clean without a secret key re-encrypts and warns" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  pubhome=$(make_pubkey_only_home)
  git config --local transcrypt.gnupghome "$pubhome"

  # no secret key: unchanged-detection is impossible; add must still
  # succeed (pubkeys suffice to encrypt) but say why the blob churns
  touch sensitive_file
  run git add sensitive_file
  [ "$status" -eq 0 ]
  [[ "$output" = *"re-encrypting"* ]]
}

@test "crypt: rekey drops removed recipient" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  git config --unset transcrypt.gpg-recipient "$BOB_FPR"
  run $TRANSCRYPT --rekey --yes
  [ "$status" -eq 0 ]

  count=$(git show :0:sensitive_file --no-textconv | recipient_count)
  [ "$count" -eq 1 ]
}

@test "crypt: handle file with problematic bytes" {
  FILENAME="problem bytes file.txt"
  printf "\375 \0 shh" > "$FILENAME"
  encrypt_named_file "$FILENAME"

  run git show HEAD:"$FILENAME" --no-textconv
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$PGP_HEADER" ]

  # checkout round trip preserves bytes
  cp "$FILENAME" "$BATS_TEST_TMPDIR/original"
  rm "$FILENAME"
  git checkout --force -- "$FILENAME"
  run cmp "$FILENAME" "$BATS_TEST_TMPDIR/original"
  rm -f "$FILENAME"
  [ "$status" -eq 0 ]
}
