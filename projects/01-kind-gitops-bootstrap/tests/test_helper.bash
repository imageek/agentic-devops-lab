# shellcheck shell=bash
# Loaded by every .bats file with `load test_helper` (or `load ../test_helper`
# from tests/smoke/).

# 1.5.0 added `run -N` (expected exit status) and `--separate-stderr`.
bats_require_minimum_version 1.5.0

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_DIR

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
