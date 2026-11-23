#!/usr/bin/env bats
# Spec for bin/log-triage: summarize plain "LEVEL message" logs.
#
#   log-triage [--top N] [--max-errors N] [FILE...]
#
# Reads the FILEs, or stdin when none are given. The first word of each line
# is its level, case-insensitive: DEBUG, INFO, WARN (WARNING counts as WARN),
# ERROR. Any other first word counts as OTHER. Blank lines are skipped.
#
# Prints a count for every level, then the --top (default 5) most frequent
# ERROR messages after normalizing them, so repeats group together:
#   timestamps -> <time>   UUIDs -> <uuid>   IPv4 -> <ip>
#   numbers not glued to a letter before them -> <n>  ("12ms" -> "<n>ms",
#     "sda1" stays)
#   runs of whitespace -> one space
# Ties are broken alphabetically.
#
# Exit status: 0 OK, 1 more ERRORs than --max-errors, 2 usage error or an
# unreadable file (message on stderr, nothing on stdout).

# bats runs each @test in its own subshell on purpose, so shellcheck's
# "modified in a subshell" warnings don't apply here.
# shellcheck disable=SC2030,SC2031

setup() {
  load test_helper
}

# The "Top errors:" section of the report, without its heading.
top_errors() {
  sed -n '/^Top errors:$/,$p' <<<"$output" | tail -n +2
}

# ---------------------------------------------------------------- report

@test "full report for a small log, in the documented format" {
  run -0 log-triage <<'LOG'
INFO service started
ERROR connection refused from 10.0.0.1
WARN disk 91% full
ERROR connection refused from 10.0.0.2
INFO request took 12ms
ERROR job 3f2a9c4e-1b7d-4e8a-9f3c-2d6b8a1e5f70 failed
LOG
  assert_equal "$output" "$(cat <<'REPORT'
ERROR 3
WARN  1
INFO  2
DEBUG 0
OTHER 0

Top errors:
    2  connection refused from <ip>
    1  job <uuid> failed
REPORT
)"
}

@test "levels are case-insensitive and WARNING counts as WARN" {
  run -0 log-triage <<'LOG'
error a
Error b
warning c
Warn d
debug e
LOG
  [[ "${lines[0]}" == "ERROR 2" ]]
  [[ "${lines[1]}" == "WARN  2" ]]
  [[ "${lines[3]}" == "DEBUG 1" ]]
}

@test "unknown first words count as OTHER; blank lines are skipped" {
  run -0 log-triage <<'LOG'
TRACE deep detail

    at com.example.Main(Main.java:12)
INFO fine
LOG
  [[ "${lines[2]}" == "INFO  1" ]]
  [[ "${lines[4]}" == "OTHER 2" ]]
}

@test "no errors: the top list says none" {
  run -0 log-triage <<<"INFO all good"
  assert_equal "$(top_errors)" "  (none)"
}

@test "empty input reports all zeros" {
  run -0 log-triage </dev/null
  [[ "${lines[0]}" == "ERROR 0" && "${lines[4]}" == "OTHER 0" ]]
}

@test "several files are added together" {
  printf 'ERROR boom\nINFO a\n' >"$BATS_TEST_TMPDIR/one.log"
  printf 'ERROR boom\n' >"$BATS_TEST_TMPDIR/two.log"
  run -0 log-triage "$BATS_TEST_TMPDIR/one.log" "$BATS_TEST_TMPDIR/two.log"
  [[ "${lines[0]}" == "ERROR 2" ]]
  assert_equal "$(top_errors)" "    2  boom"
}

# ---------------------------------------------------------------- normalizing

@test "numbers become <n>, including ones before a unit" {
  run -0 log-triage <<'LOG'
ERROR retry 3 of 5 took 120ms
ERROR retry 4 of 5 took 98ms
LOG
  assert_equal "$(top_errors)" "    2  retry <n> of <n> took <n>ms"
}

@test "digits glued to a letter before them are kept" {
  run -0 log-triage <<'LOG'
ERROR /dev/sda1 is read-only
ERROR /dev/sdb2 is read-only
LOG
  assert_equal "$(top_errors)" "$(printf '%s\n' \
    "    1  /dev/sda1 is read-only" \
    "    1  /dev/sdb2 is read-only")"
}

@test "IPv4 addresses become <ip>, ports become <n>" {
  run -0 log-triage <<'LOG'
ERROR upstream 192.168.1.10:8080 timed out
ERROR upstream 10.1.2.3:9090 timed out
LOG
  assert_equal "$(top_errors)" "    2  upstream <ip>:<n> timed out"
}

@test "UUIDs become <uuid>, in either case" {
  run -0 log-triage <<'LOG'
ERROR job 3f2a9c4e-1b7d-4e8a-9f3c-2d6b8a1e5f70 failed
ERROR job 9B1E2C3D-4F5A-4B6C-8D7E-0F1A2B3C4D5E failed
LOG
  assert_equal "$(top_errors)" "    2  job <uuid> failed"
}

@test "timestamps become <time>" {
  run -0 log-triage <<'LOG'
ERROR lease expired at 2026-11-23T10:15:00Z
ERROR lease expired at 2026-11-23 10:16:30.123+01:00
ERROR lease expired at 2026-11-24
LOG
  assert_equal "$(top_errors)" "    3  lease expired at <time>"
}

@test "runs of whitespace collapse to one space" {
  run -0 log-triage <<<$'ERROR   disk \t full  '
  assert_equal "$(top_errors)" "    1  disk full"
}

# ---------------------------------------------------------------- top list

@test "only ERROR lines make the top list" {
  run -0 log-triage <<'LOG'
WARN slow
WARN slow
ERROR broken
LOG
  assert_equal "$(top_errors)" "    1  broken"
}

@test "sorted by count, ties alphabetical, capped by --top" {
  run -0 log-triage --top 3 <<'LOG'
ERROR c
ERROR b
ERROR a
ERROR d
ERROR d
ERROR e
LOG
  assert_equal "$(top_errors)" "$(printf '%s\n' \
    "    2  d" \
    "    1  a" \
    "    1  b")"
}

@test "the top list defaults to 5" {
  run -0 log-triage <<<"$(printf 'ERROR e%s\n' a b c d e f g)"
  [[ "$(top_errors | wc -l | tr -d ' ')" == 5 ]]
}

# ---------------------------------------------------------------- --max-errors

@test "--max-errors: at the limit is fine, over it exits 1 with the report" {
  run -0 log-triage --max-errors 2 <<<$'ERROR a\nERROR b'
  run -1 log-triage --max-errors 1 <<<$'ERROR a\nERROR b'
  [[ "${lines[0]}" == "ERROR 2" ]]
}

@test "--max-errors 0 passes a clean log" {
  run -0 log-triage --max-errors 0 <<<"INFO ok"
}

# ---------------------------------------------------------------- scale

@test "100k lines in under 10 seconds" {
  awk 'BEGIN { for (i = 0; i < 100000; i++) print "ERROR request " i " failed" }' \
    >"$BATS_TEST_TMPDIR/big.log"
  local start=$SECONDS
  run -0 log-triage "$BATS_TEST_TMPDIR/big.log"
  ((SECONDS - start < 10))
  assert_equal "$(top_errors)" "100000  request <n> failed"
}

# ---------------------------------------------------------------- usage

# Usage errors: exit 2, say why on stderr, print nothing on stdout.
assert_usage_error() {
  run -2 --separate-stderr log-triage "$@" </dev/null
  [[ -z "$output" ]]
  [[ -n "$stderr" ]]
}

@test "usage error: file that doesn't exist" {
  assert_usage_error "$BATS_TEST_TMPDIR/missing.log"
}

@test "usage error: --top not a positive whole number" {
  assert_usage_error --top 0
}

@test "usage error: --max-errors not a whole number" {
  assert_usage_error --max-errors lots
}

@test "usage error: unknown option" {
  assert_usage_error --json
}

@test "--help prints usage on stdout and exits 0" {
  run -0 log-triage --help
  [[ "$output" == *"--top"* && "$output" == *"--max-errors"* ]]
}
