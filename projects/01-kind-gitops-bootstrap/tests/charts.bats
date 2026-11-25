#!/usr/bin/env bats
# The pre-merge gate on the charts: render them as Argo CD would and assert on
# the manifests. Merging to main is the deploy here, so these checks are what
# stop a bad chart before Argo CD ever syncs it. No cluster needed.
#
# kubeconform (in `make test`) checks the schema; these check the content.
# helm renders, yq (yq_json in test_helper) turns the YAML stream into one
# JSON array, and jq asserts on it.

# render CHART [helm args...]
#   Prints the rendered chart as a JSON array, one element per manifest.
render() {
  helm template test "$PROJECT_DIR/charts/$1" "${@:2}" | yq_json
}

# Shared jq definitions, so each check reads as one line.
# shellcheck disable=SC2016  # $name is a jq variable, not a shell one
readonly JQ_DEFS='
  def deployment: .[] | select(.kind == "Deployment");
  def pod: deployment | .spec.template.spec;
  def containers: pod | .containers[];
  def app($name): .[] | select(.kind == "Application" and .metadata.name == $name);
'

# assert_jq FILE FILTER
#   FILTER must output true. On failure, prints the filter.
assert_jq() {
  jq -e "$JQ_DEFS $2" "$1" >/dev/null || {
    echo "not true: $2"
    return 1
  }
}

setup_file() {
  load test_helper
  render hello >"$BATS_FILE_TMPDIR/hello.json"
  render apps >"$BATS_FILE_TMPDIR/apps.json"
}

setup() {
  load test_helper
  HELLO="$BATS_FILE_TMPDIR/hello.json"
  APPS="$BATS_FILE_TMPDIR/apps.json"
}

# ---------------------------------------------------------------- hello: shape

@test "hello renders one Deployment, one Service and one ConfigMap" {
  assert_jq "$HELLO" '[.[].kind] | sort == ["ConfigMap", "Deployment", "Service"]'
}

# ---------------------------------------------------------------- hello: security

@test "hello pods run as non-root with the default seccomp profile" {
  assert_jq "$HELLO" 'pod.securityContext.runAsNonRoot == true'
  assert_jq "$HELLO" 'pod.securityContext.seccompProfile.type == "RuntimeDefault"'
}

@test "hello containers can't escalate and drop all capabilities" {
  assert_jq "$HELLO" '[containers | .securityContext.allowPrivilegeEscalation == false] | all'
  assert_jq "$HELLO" '[containers | .securityContext.capabilities.drop | index("ALL") != null] | all'
}

@test "hello mounts its page read-only" {
  assert_jq "$HELLO" '[containers | .volumeMounts[] | .readOnly == true] | all'
}

# ---------------------------------------------------------------- hello: operability

@test "hello containers set requests and a memory limit" {
  assert_jq "$HELLO" '[containers | .resources.requests.cpu and .resources.requests.memory] | all'
  assert_jq "$HELLO" '[containers | .resources.limits.memory != null] | all'
}

@test "hello containers have readiness and liveness probes" {
  assert_jq "$HELLO" '[containers | .readinessProbe != null and .livenessProbe != null] | all'
}

@test "hello images are pinned to a tag other than latest" {
  assert_jq "$HELLO" '[containers | .image | test(":[^:/]+$") and (endswith(":latest") | not)] | all'
}

# ---------------------------------------------------------------- hello: regressions

# PR #2: `indent` instead of `nindent` broke the YAML for multi-line messages.
@test "a multi-line message reaches the page exactly" {
  local message=$'Line one\n  indented: looks like YAML\n\nlast line\n'
  printf '%s' "$message" >"$BATS_TEST_TMPDIR/message.txt"
  render hello --set-file message="$BATS_TEST_TMPDIR/message.txt" >"$BATS_TEST_TMPDIR/out.json"
  local page
  page=$(jq -r '.[] | select(.kind == "ConfigMap") | .data["index.html"]' "$BATS_TEST_TMPDIR/out.json")
  # $(...) drops trailing newlines from both sides alike.
  assert_equal "$page" "$(printf '%s' "$message")"
}

@test "changing the message changes checksum/config, so pods roll" {
  local filter='.[] | select(.kind == "Deployment") | .spec.template.metadata.annotations["checksum/config"]'
  local one two again
  one=$(render hello --set message=one | jq -r "$filter")
  two=$(render hello --set message=two | jq -r "$filter")
  again=$(render hello --set message=one | jq -r "$filter")
  [[ -n "$one" && "$one" != null ]]
  [[ "$one" != "$two" ]]
  [[ "$one" == "$again" ]]
}

# ---------------------------------------------------------------- apps

@test "the hello Application tracks main by default" {
  assert_jq "$APPS" 'app("hello").spec.source.targetRevision == "main"'
}

@test "the hello Application follows the revision the root app passes down" {
  render apps --set revision=feat/try-me >"$BATS_TEST_TMPDIR/out.json"
  assert_jq "$BATS_TEST_TMPDIR/out.json" 'app("hello").spec.source.targetRevision == "feat/try-me"'
}

@test "the hello Application points at a chart that exists in this repo" {
  local path
  path=$(jq -r "$JQ_DEFS app(\"hello\").spec.source.path" "$APPS")
  [[ -f "$PROJECT_DIR/../../$path/Chart.yaml" ]] || {
    echo "no chart at $path"
    return 1
  }
}

@test "the hello Application syncs automatically, with prune and selfHeal" {
  assert_jq "$APPS" 'app("hello").spec.syncPolicy.automated | .prune == true and .selfHeal == true'
}
