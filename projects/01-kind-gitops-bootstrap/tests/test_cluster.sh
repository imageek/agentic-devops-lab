#!/usr/bin/env bash
# Tests scripts/cluster.sh against fake kind and kubectl binaries, so no
# cluster is created or contacted.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROJECT_DIR
readonly SCRIPT="${PROJECT_DIR}/scripts/cluster.sh"

WORK_DIR="$(mktemp -d)"
readonly WORK_DIR
trap 'rm -rf "${WORK_DIR}"' EXIT

export CALLS="${WORK_DIR}/calls"
export PATH="${WORK_DIR}:${PATH}"

write_fakes() {
  cat >"${WORK_DIR}/kind" <<'EOF'
#!/usr/bin/env bash
echo "kind $*" >>"${CALLS}"
if [[ "$1 $2" == "get clusters" ]]; then
  printf '%s\n' "${FAKE_CLUSTERS:-}"
fi
EOF
  cat >"${WORK_DIR}/kubectl" <<'EOF'
#!/usr/bin/env bash
echo "kubectl $*" >>"${CALLS}"
if [[ "$1 $2" == "config current-context" ]]; then
  [[ -n "${FAKE_CONTEXT:-}" ]] || exit 1
  echo "${FAKE_CONTEXT}"
fi
EOF
  chmod +x "${WORK_DIR}/kind" "${WORK_DIR}/kubectl"
}

reset_calls() {
  : >"${CALLS}"
}

fail() {
  echo "FAIL: $1" >&2
  echo "--- calls" >&2
  cat "${CALLS}" >&2
  exit 1
}

assert_called() {
  grep -qF -- "$1" "${CALLS}" || fail "expected call: $1"
}

assert_not_called() {
  if grep -qF -- "$1" "${CALLS}"; then
    fail "unexpected call: $1"
  fi
}

test_up_creates_lab_and_restores_context() {
  reset_calls
  FAKE_CLUSTERS="multi" FAKE_CONTEXT="kind-multi" KIND_CLUSTER_NAME="multi" \
    "${SCRIPT}" up >/dev/null
  assert_called "kind create cluster --name lab "
  assert_called "kubectl config use-context kind-multi"
  assert_called "kubectl --context kind-lab get nodes"
}

test_up_without_previous_context_switches_nothing() {
  reset_calls
  FAKE_CLUSTERS="" FAKE_CONTEXT="" "${SCRIPT}" up >/dev/null
  assert_called "kind create cluster --name lab "
  assert_not_called "use-context"
}

test_up_is_idempotent() {
  reset_calls
  FAKE_CLUSTERS="$(printf 'lab\nmulti')" FAKE_CONTEXT="kind-multi" \
    "${SCRIPT}" up >/dev/null
  assert_not_called "kind create"
  assert_not_called "use-context"
}

test_down_only_deletes_lab() {
  reset_calls
  KIND_CLUSTER_NAME="multi" "${SCRIPT}" down >/dev/null
  assert_called "kind delete cluster --name lab"
  assert_not_called "multi"
}

test_bad_usage_calls_nothing() {
  local args
  for args in "" "multi" "down multi"; do
    reset_calls
    local status=0
    # shellcheck disable=SC2086 # Word splitting builds the argument list.
    "${SCRIPT}" ${args} >/dev/null 2>&1 || status=$?
    [[ "${status}" -eq 2 ]] || fail "'${args}' exited ${status}, expected 2"
    [[ ! -s "${CALLS}" ]] || fail "'${args}' should not call kind or kubectl"
  done
}

main() {
  write_fakes
  test_up_creates_lab_and_restores_context
  test_up_without_previous_context_switches_nothing
  test_up_is_idempotent
  test_down_only_deletes_lab
  test_bad_usage_calls_nothing
  echo "test_cluster: ok"
}

main "$@"
