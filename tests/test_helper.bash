# Common test setup
setup() {
  TEST_TMP="$BATS_TEST_TMPDIR"
  mkdir -p "$TEST_TMP"
}

teardown() {
  rm -rf "$TEST_TMP"
}
