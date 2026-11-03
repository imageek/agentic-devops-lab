#!/usr/bin/env bash
# Checks the running kind-lab cluster: Argo CD has synced both applications and
# the hello app serves its page.
set -euo pipefail

readonly CONTEXT="kind-lab"
readonly TIMEOUT_SECONDS="${SMOKE_TIMEOUT:-180}"

app_status() {
  kubectl --context "${CONTEXT}" -n argocd get application "$1" \
    -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null || true
}

wait_for_app() {
  local app="$1" status=""
  local deadline=$((SECONDS + TIMEOUT_SECONDS))
  while ((SECONDS < deadline)); do
    status="$(app_status "${app}")"
    if [[ "${status}" == "Synced/Healthy" ]]; then
      echo "application ${app}: ${status}"
      return 0
    fi
    sleep 5
  done
  echo "FAIL: application ${app} is '${status:-missing}' after ${TIMEOUT_SECONDS}s" >&2
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
