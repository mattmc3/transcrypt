#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/_gpg_helper.bash"

# Operations that only make sense for the password-based legacy format
# must refuse loudly on gpg-format repositories instead of half-working.

@test "unsupported: --upgrade refuses on the gpg format" {
  run $TRANSCRYPT --upgrade --yes
  [ "$status" -ne 0 ]
  [[ "$output" = *"not supported with the gpg format"* ]]
}

@test "unsupported: --flush-credentials refuses on the gpg format" {
  run $TRANSCRYPT --flush-credentials --yes
  [ "$status" -ne 0 ]
  [[ "$output" = *"not supported with the gpg format"* ]]
}

@test "unsupported: --context refuses on the gpg format" {
  run $TRANSCRYPT --context=super --cipher=aes-256-cbc --password=x --yes
  [ "$status" -ne 0 ]
  [[ "$output" = *"not supported with the gpg format"* ]]
}

@test "unsupported: --export-gpg refuses on the gpg format" {
  run $TRANSCRYPT --export-gpg="$ALICE" --yes
  [ "$status" -ne 0 ]
  [[ "$output" = *"not supported with the gpg format"* ]]
}

@test "unsupported: --import-gpg refuses on the gpg format" {
  echo "bogus" > import_file
  run $TRANSCRYPT --import-gpg=import_file --yes
  [ "$status" -ne 0 ]
  [[ "$output" = *"not supported with the gpg format"* ]]
}
