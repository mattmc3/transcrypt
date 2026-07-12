#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/_gpg_helper.bash"

@test "merge: branches with encrypted file - addition, no conflict" {
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

@test "merge: branches with encrypted file - line changes both branches, no conflict" {
  echo "1. First step" > sensitive_file
  echo "2. Second step" >> sensitive_file
  encrypt_named_file sensitive_file

  git checkout -b branch-2
  echo "1. Step the first" > sensitive_file
  echo "2. Second step" >> sensitive_file
  git add sensitive_file
  git commit -m "Change line 1"

  git checkout -

  echo "1. First step" > sensitive_file
  echo "2. Second step" >> sensitive_file
  echo "3. Third step" >> sensitive_file
  git add sensitive_file
  git commit -m "Add line 3"

  run git merge branch-2
  [ "$status" -eq 0 ]

  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "1. Step the first" ]
  [ "${lines[1]}" = "2. Second step" ]
  [ "${lines[2]}" = "3. Third step" ]
}

@test "merge: refuses to merge secrets it cannot decrypt" {
  echo "1. First step" > sensitive_file
  encrypt_named_file sensitive_file

  git checkout -b branch-2
  echo "1. Branch version" > sensitive_file
  git add sensitive_file
  git commit -m "Branch change"

  git checkout -
  echo "1. Main version" > sensitive_file
  git add sensitive_file
  git commit -m "Main change"

  # merge on a machine with no secret key: the driver must abort, not
  # merge raw armor text and re-encrypt the garbage as if it were plaintext
  pubhome=$(make_pubkey_only_home)
  git config --local transcrypt.gnupghome "$pubhome"

  run git merge branch-2
  [ "$status" -ne 0 ]
  [[ "$output" = *"cannot decrypt"* ]]

  # no merge commit was created (main had 2 commits before the merge)
  [ "$(git rev-list --count HEAD)" -eq 2 ]

  # the working copy keeps its pre-merge content, not merged garbage
  run cat sensitive_file
  [ "${lines[0]}" = "1. Main version" ]
}

@test "merge: conflicting changes leave merge markers in plaintext" {
  echo "1. First step" > sensitive_file
  encrypt_named_file sensitive_file

  git checkout -b branch-2
  echo "1. Branch version" > sensitive_file
  git add sensitive_file
  git commit -m "Branch change"

  git checkout -
  echo "1. Main version" > sensitive_file
  git add sensitive_file
  git commit -m "Main change"

  run git merge branch-2
  [ "$status" -ne 0 ]

  # conflict markers surround plaintext, not ciphertext
  run cat sensitive_file
  [[ "$output" = *"<<<<<<<"* ]]
  [[ "$output" = *"1. Main version"* ]]
  [[ "$output" = *"1. Branch version"* ]]
}
