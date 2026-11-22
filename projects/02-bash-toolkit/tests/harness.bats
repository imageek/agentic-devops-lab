#!/usr/bin/env bats
# Proves the harness works before any toolkit code exists.

setup() {
  load test_helper
}

@test "helper puts the toolkit's bin/ first on PATH" {
  [[ "$PATH" == "$TOOLKIT_BIN:"* ]]
}

@test "run -N checks the exit status" {
  run -3 bash -c 'echo out; exit 3'
  [[ "$output" == "out" ]]
}

@test "--separate-stderr keeps stdout and stderr apart" {
  run --separate-stderr bash -c 'echo out; echo err >&2'
  [[ "$output" == "out" ]]
  [[ "$stderr" == "err" ]]
}
