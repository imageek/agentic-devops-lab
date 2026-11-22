#!/usr/bin/env bats
# Spec for bin/cert-expiry: report how long the TLS cert served at host:port
# has left, Nagios-style.
#
#   cert-expiry [--warn DAYS] [--crit DAYS] HOST:PORT...
#
# Days left are rounded down. For each target:
#   CRIT     if days left < --crit (default 30), or already expired
#   WARN     if days left <= --warn (default 60)
#   OK       otherwise
#   UNKNOWN  if no cert could be fetched
# One line per target, in argument order. Exit status is the worst result:
#   CRIT 2 > UNKNOWN 3 > WARN 1 > OK 0
# Usage errors exit 3 with a message on stderr and nothing on stdout.
#
# CERT_EXPIRY_NOW (epoch seconds) stands in for the clock, so threshold
# boundaries are tested exactly.

# bats runs each @test in its own subshell on purpose, so shellcheck's
# "modified in a subshell" warnings don't apply here.
# shellcheck disable=SC2030,SC2031

LATE_EXPIRY=2208988800  # 2040-01-01T00:00:00Z
EARLY_EXPIRY=1830297600 # 2028-01-01T00:00:00Z
DAY=86400

setup_file() {
  load tls_fixture
  start_tls_server LATE 20400101000000Z
  start_tls_server EARLY 20280101000000Z
}

teardown_file() {
  load tls_fixture
  stop_tls_servers
}

setup() {
  load test_helper
}

# Pretend it's SECONDS before LATE's expiry.
before_late() {
  export CERT_EXPIRY_NOW=$((LATE_EXPIRY - $1))
}

# ---------------------------------------------------------------- thresholds

@test "more than 60 days left is OK, in the documented format" {
  before_late $((61 * DAY))
  run -0 cert-expiry "$LATE"
  [[ "$output" == "OK $LATE 61 days left (expires 2040-01-01)" ]]
}

@test "exactly 60 days left is WARN" {
  before_late $((60 * DAY))
  run -1 cert-expiry "$LATE"
  [[ "$output" == "WARN $LATE 60 days left (expires 2040-01-01)" ]]
}

@test "partial days round down: 60.5 days is 60, so WARN" {
  before_late $((60 * DAY + DAY / 2))
  run -1 cert-expiry "$LATE"
  [[ "$output" == "WARN $LATE 60 days left"* ]]
}

@test "exactly 30 days left is still WARN" {
  before_late $((30 * DAY))
  run -1 cert-expiry "$LATE"
  [[ "$output" == "WARN $LATE 30 days left"* ]]
}

@test "under 30 days left is CRIT" {
  before_late $((30 * DAY - 1))
  run -2 cert-expiry "$LATE"
  [[ "$output" == "CRIT $LATE 29 days left"* ]]
}

@test "an expired cert is CRIT" {
  before_late -3600
  run -2 cert-expiry "$LATE"
  [[ "$output" == "CRIT $LATE expired (expired 2040-01-01)" ]]
}

@test "--warn and --crit override the defaults" {
  before_late $((11 * DAY))
  run -0 cert-expiry --warn 10 --crit 5 "$LATE"
  before_late $((10 * DAY))
  run -1 cert-expiry --warn 10 --crit 5 "$LATE"
  before_late $((4 * DAY))
  run -2 cert-expiry --warn 10 --crit 5 "$LATE"
}

@test "without CERT_EXPIRY_NOW it uses the real clock" {
  unset CERT_EXPIRY_NOW
  local now days
  now=$(date +%s)
  days=$(((LATE_EXPIRY - now) / DAY))
  run -0 cert-expiry "$LATE"
  # Allow one day either side in case the run crosses midnight.
  [[ "$output" =~ ^OK\ $LATE\ ([0-9]+)\ days ]]
  ((BASH_REMATCH[1] >= days - 1 && BASH_REMATCH[1] <= days + 1))
}

# ---------------------------------------------------------------- failures

@test "nothing listening is UNKNOWN" {
  run -3 cert-expiry 127.0.0.1:1
  [[ "$output" == "UNKNOWN 127.0.0.1:1"* ]]
}

# ---------------------------------------------------------------- several targets

@test "one line per target, in argument order; worst result wins" {
  export CERT_EXPIRY_NOW=$((EARLY_EXPIRY + DAY)) # EARLY expired, LATE fine
  run -2 cert-expiry "$LATE" "$EARLY"
  ((${#lines[@]} == 2))
  [[ "${lines[0]}" == "OK $LATE "* ]]
  [[ "${lines[1]}" == "CRIT $EARLY expired"* ]]
}

@test "CRIT outranks UNKNOWN" {
  export CERT_EXPIRY_NOW=$((EARLY_EXPIRY + DAY))
  run -2 cert-expiry 127.0.0.1:1 "$EARLY"
  [[ "${lines[0]}" == "UNKNOWN 127.0.0.1:1"* ]]
  [[ "${lines[1]}" == "CRIT $EARLY"* ]]
}

@test "UNKNOWN outranks WARN" {
  before_late $((45 * DAY))
  run -3 cert-expiry "$LATE" 127.0.0.1:1
  [[ "${lines[0]}" == "WARN $LATE"* ]]
  [[ "${lines[1]}" == "UNKNOWN 127.0.0.1:1"* ]]
}

# ---------------------------------------------------------------- usage

# Usage errors: exit 3, say why on stderr, print nothing on stdout.
assert_usage_error() {
  run -3 --separate-stderr cert-expiry "$@"
  [[ -z "$output" ]]
  [[ -n "$stderr" ]]
}

@test "usage error: no targets" {
  assert_usage_error
}

@test "usage error: target without a port" {
  assert_usage_error localhost
}

@test "usage error: non-numeric threshold" {
  assert_usage_error --warn soon "$LATE"
}

@test "usage error: --crit above --warn" {
  assert_usage_error --warn 10 --crit 20 "$LATE"
}

@test "usage error: unknown option" {
  assert_usage_error --verbose "$LATE"
}

@test "--help prints usage on stdout and exits 0" {
  run -0 cert-expiry --help
  [[ "$output" == *"--warn"* && "$output" == *"--crit"* ]]
}
