#!/usr/bin/env bash
# Checks that the playbook refuses to run against another context. The context
# used here doesn't exist, so even a broken guard couldn't reach a real cluster.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROJECT_DIR

main() {
  local output status=0
  output="$(
    ansible-playbook \
      -i "${PROJECT_DIR}/ansible/inventory.yml" \
      "${PROJECT_DIR}/ansible/bootstrap.yml" \
      -e kube_context=kind-does-not-exist 2>&1
  )" || status=$?

  if [[ "${status}" -eq 0 ]]; then
    echo "FAIL: playbook accepted another context" >&2
    exit 1
  fi
  if ! grep -qF "only runs against kind-lab" <<<"${output}"; then
    echo "FAIL: playbook failed for the wrong reason:" >&2
    echo "${output}" >&2
    exit 1
  fi
  echo "test_playbook_guard: ok"
}

main "$@"
