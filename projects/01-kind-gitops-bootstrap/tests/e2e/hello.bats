#!/usr/bin/env bats
# Installs the hello chart from this working tree into kind-lab with Helm and
# checks the running result (`make e2e`). CI runs it on a throwaway kind
# cluster for every PR, so a chart that renders but won't run can't merge.
#
# It uses its own release and namespace (hello-e2e), so on your machine it
# sits beside the Argo CD-managed hello without touching it. Set E2E_KEEP=1
# to leave the release running after the tests, for debugging.
#
# Tests run in file order; the last one upgrades the release.
#
# No live read-only check on the page mount: Kubernetes mounts ConfigMap
# volumes read-only whatever the chart says, so it could never fail. The
# chart's readOnly setting is checked in tests/charts.bats instead.

readonly CONTEXT=kind-lab
readonly NS=hello-e2e
readonly RELEASE=hello-e2e

setup_file() {
  load ../test_helper
  helm --kube-context "$CONTEXT" upgrade --install "$RELEASE" "$PROJECT_DIR/charts/hello" \
    --namespace "$NS" --create-namespace --wait --timeout 180s
}

teardown_file() {
  [[ -z "${E2E_KEEP:-}" ]] || return 0
  helm --kube-context "$CONTEXT" uninstall "$RELEASE" --namespace "$NS" --wait --ignore-not-found
  # Wait, so an immediate re-run doesn't find the namespace still terminating.
  kubectl --context "$CONTEXT" delete namespace "$NS" --ignore-not-found --timeout 120s
}

setup() {
  load ../test_helper
}

k() {
  kubectl --context "$CONTEXT" --namespace "$NS" "$@"
}

# The page as served through the Service, via the API server's proxy.
served_page() {
  kubectl --context "$CONTEXT" get --raw "/api/v1/namespaces/$NS/services/$RELEASE:http/proxy/"
}

@test "the Deployment is Available with every pod Ready" {
  run -0 k rollout status "deployment/$RELEASE" --timeout 60s
  local want ready
  want=$(k get deployment "$RELEASE" -o jsonpath='{.spec.replicas}')
  ready=$(k get deployment "$RELEASE" -o jsonpath='{.status.readyReplicas}')
  [[ "$ready" == "$want" ]] || {
    echo "ready $ready of $want"
    return 1
  }
}

@test "no container has restarted" {
  local restarts
  restarts=$(k get pods -l "app.kubernetes.io/instance=$RELEASE" \
    -o jsonpath='{range .items[*].status.containerStatuses[*]}{.restartCount}{"\n"}{end}')
  [[ -n "$restarts" ]]
  [[ "$(sort -nr <<<"$restarts" | head -n 1)" == 0 ]] || {
    echo "restart counts: $restarts"
    return 1
  }
}

@test "the container really runs as a non-root user" {
  run -0 k exec "deployment/$RELEASE" -c nginx -- id -u
  [[ "$output" =~ ^[0-9]+$ ]] && ((output != 0))
}

@test "the Service serves exactly the page the chart renders" {
  assert_equal "$(served_page)" "$(rendered_page)"
}

@test "a new message rolls out new pods that serve it" {
  local message before after
  message="Rolled out by e2e at $(date +%s)"
  before=$(k get pods -l "app.kubernetes.io/instance=$RELEASE" -o name)
  helm --kube-context "$CONTEXT" upgrade "$RELEASE" "$PROJECT_DIR/charts/hello" \
    --namespace "$NS" --reuse-values --set message="$message" --wait --timeout 120s
  after=$(k get pods -l "app.kubernetes.io/instance=$RELEASE" --field-selector=status.phase=Running -o name)
  [[ -n "$after" && "$after" != "$before" ]] || {
    echo "pods didn't change: $before"
    return 1
  }
  assert_equal "$(served_page)" "$(rendered_page --set message="$message")"
}
