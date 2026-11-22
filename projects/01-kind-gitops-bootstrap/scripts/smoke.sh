#!/usr/bin/env bash
# Checks the running kind-lab cluster: Argo CD has synced both applications
# from the expected Git revision, and the hello app serves its page.
#
# Set GITOPS_REVISION to the branch you passed to `make up` (default: main).
set -euo pipefail

readonly CONTEXT="kind-lab"
readonly TIMEOUT_SECONDS="${SMOKE_TIMEOUT:-180}"
readonly EXPECTED_REVISION="${GITOPS_REVISION:-main}"

# Prints "<revision> <sync>/<health>". The revision is the one Argo CD last
# compared against, so "Synced" is known to refer to that revision.
app_status() {
  kubectl --context "${CONTEXT}" -n argocd get application "$1" \
    -o jsonpath='{.status.sync.comparedTo.source.targetRevision} {.status.sync.status}/{.status.health.status}' \
    2>/dev/null || true
}

wait_for_app() {
  local app="$1" status=""
  local want="${EXPECTED_REVISION} Synced/Healthy"
  local deadline=$((SECONDS + TIMEOUT_SECONDS))
  while ((SECONDS < deadline)); do
    status="$(app_status "${app}")"
    if [[ "${status}" == "${want}" ]]; then
      echo "application ${app}: ${status}"
      return 0
    fi
    sleep 5
  done
  echo "FAIL: application ${app} is '${status:-missing}', want '${want}' after ${TIMEOUT_SECONDS}s" >&2
  return 1
}

check_page() {
  local page
  page="$(kubectl --context "${CONTEXT}" get --raw \
    /api/v1/namespaces/hello/services/hello:http/proxy/)"
  if [[ -z "${page}" ]]; then
    echo "FAIL: hello returned an empty page" >&2
    return 1
  fi
  echo "hello says: ${page}"
}

main() {
  wait_for_app root
  wait_for_app hello
  check_page
}

main "$@"
