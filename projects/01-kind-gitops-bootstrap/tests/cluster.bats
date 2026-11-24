#!/usr/bin/env bats
# scripts/cluster.sh against fake kind and kubectl binaries, so no cluster is
# created or contacted. The fakes log every call to $CALLS.

setup() {
  load test_helper
  SCRIPT="$PROJECT_DIR/scripts/cluster.sh"
  export CALLS="$BATS_TEST_TMPDIR/calls"
  : >"$CALLS"

  local fakes="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fakes"
  # FAKE_CLUSTERS: what `kind get clusters` prints.
  cat >"$fakes/kind" <<'FAKE'
#!/usr/bin/env bash
echo "kind $*" >>"$CALLS"
if [[ "$1 $2" == "get clusters" ]]; then
  printf '%s\n' "${FAKE_CLUSTERS:-}"
fi
FAKE
  # FAKE_CONTEXT: the current context; unset means kubectl has none.
  cat >"$fakes/kubectl" <<'FAKE'
#!/usr/bin/env bash
echo "kubectl $*" >>"$CALLS"
if [[ "$1 $2" == "config current-context" ]]; then
  [[ -n "${FAKE_CONTEXT:-}" ]] || exit 1
  echo "$FAKE_CONTEXT"
fi
FAKE
  chmod +x "$fakes/kind" "$fakes/kubectl"
  PATH="$fakes:$PATH"
}

# On failure, show what was called; bats prints a failing test's output.
assert_called() {
  grep -qF -- "$1" "$CALLS" || {
    echo "expected call: $1"
    echo "-- calls:"
    cat "$CALLS"
    return 1
  }
}

assert_not_called() {
  ! grep -qF -- "$1" "$CALLS" || {
    echo "unexpected call: $1"
    echo "-- calls:"
    cat "$CALLS"
    return 1
  }
}

@test "up creates kind-lab and restores the previous context" {
  FAKE_CLUSTERS="multi" FAKE_CONTEXT="kind-multi" KIND_CLUSTER_NAME="multi" \
    run -0 "$SCRIPT" up
  assert_called "kind create cluster --name lab "
  assert_called "kubectl config use-context kind-multi"
  assert_called "kubectl --context kind-lab get nodes"
}

@test "up with no previous context switches nothing back" {
  FAKE_CLUSTERS="" FAKE_CONTEXT="" run -0 "$SCRIPT" up
  assert_called "kind create cluster --name lab "
  assert_not_called "use-context"
}

@test "up is idempotent: an existing kind-lab is left alone" {
  FAKE_CLUSTERS="$(printf 'lab\nmulti')" FAKE_CONTEXT="kind-multi" run -0 "$SCRIPT" up
  assert_not_called "kind create"
  assert_not_called "use-context"
}

@test "down deletes only kind-lab, whatever KIND_CLUSTER_NAME says" {
  KIND_CLUSTER_NAME="multi" run -0 "$SCRIPT" down
  assert_called "kind delete cluster --name lab"
  assert_not_called "multi"
}

# Usage errors exit 2 and must not touch kind or kubectl at all.
assert_bad_usage() {
  run -2 "$SCRIPT" "$@"
  [[ ! -s "$CALLS" ]] || {
    echo "bad usage should call nothing, but called:"
    cat "$CALLS"
    return 1
  }
}

@test "bad usage: no arguments" {
  assert_bad_usage
}

@test "bad usage: a cluster name instead of up/down" {
  assert_bad_usage multi
}

@test "bad usage: an extra argument after down" {
  assert_bad_usage down multi
}
