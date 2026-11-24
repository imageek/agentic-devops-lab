# shellcheck shell=bash
# Loaded by every .bats file with `load test_helper`.

# 1.5.0 added `run -N` (expected exit status) and `--separate-stderr`.
bats_require_minimum_version 1.5.0

# Put the toolkit's scripts first on PATH, so tests call them by name.
TOOLKIT_BIN="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bin"
export TOOLKIT_BIN
PATH="$TOOLKIT_BIN:$PATH"

# assert_equal ACTUAL EXPECTED
#   Exact comparison that prints a diff on failure, since plain bats only
#   shows the line that failed.
assert_equal() {
  if [[ "$1" != "$2" ]]; then
    echo "-- expected (-) vs actual (+):"
    diff -u <(printf '%s\n' "$2") <(printf '%s\n' "$1") | tail -n +3
    return 1
  fi
}
