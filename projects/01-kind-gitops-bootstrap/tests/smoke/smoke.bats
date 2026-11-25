#!/usr/bin/env bats
# Smoke test for the running kind-lab cluster (`make smoke`): Argo CD has
# synced both applications from the expected Git revision, and hello serves
# exactly the page its chart renders.
#
# Set GITOPS_REVISION to the branch you passed to `make up` (default: main).
# SMOKE_TIMEOUT (seconds, default 180) caps each wait for Argo CD.
# The page is compared with the chart in this working tree, so run it from a
# checkout of the revision Argo CD is tracking.
#
# Lives in tests/smoke/ because `bats tests` doesn't descend into subfolders,
# so `make test` stays cluster-free.

readonly CONTEXT=kind-lab

setup() {
  load ../test_helper
  EXPECTED_REVISION=${GITOPS_REVISION:-main}
  TIMEOUT_SECONDS=${SMOKE_TIMEOUT:-180}
}

# Prints "<revision> <sync>/<health>". The revision is the one Argo CD last
# compared against, so "Synced" is known to refer to that revision.
app_status() {
  kubectl --context "$CONTEXT" -n argocd get application "$1" \
    -o jsonpath='{.status.sync.comparedTo.source.targetRevision} {.status.sync.status}/{.status.health.status}' \
    2>/dev/null || true
}

# wait_for_app NAME: poll until NAME is Synced/Healthy at the expected revision.
wait_for_app() {
  local app=$1 status=""
  local want="$EXPECTED_REVISION Synced/Healthy"
  local deadline=$((SECONDS + TIMEOUT_SECONDS))
  while ((SECONDS < deadline)); do
    status=$(app_status "$app")
    [[ "$status" == "$want" ]] && return 0
    sleep 5
  done
  echo "application $app is '${status:-missing}', want '$want' after ${TIMEOUT_SECONDS}s"
  return 1
}

@test "the root application is Synced/Healthy at the expected revision" {
  wait_for_app root
}

@test "the hello application is Synced/Healthy at the expected revision" {
  wait_for_app hello
}

@test "hello serves exactly the page its chart renders" {
  local expected page
  expected=$(rendered_page)
  page=$(kubectl --context "$CONTEXT" get --raw \
    /api/v1/namespaces/hello/services/hello:http/proxy/)
  assert_equal "$page" "$expected"
}
