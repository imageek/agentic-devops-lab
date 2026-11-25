# shellcheck shell=bash
# Loaded by every .bats file with `load test_helper` (or `load ../test_helper`
# from tests/smoke/).

# 1.5.0 added `run -N` (expected exit status) and `--separate-stderr`.
bats_require_minimum_version 1.5.0

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_DIR

# assert_equal ACTUAL EXPECTED
#   Exact comparison that prints a diff on failure, since plain bats only
#   shows the line that failed.
assert_equal() {
  if [[ "$1" != "$2" ]]; then
    echo "-- expected (-) vs actual (+):"
    diff -u <(printf '%s\n' "$2") <(printf '%s\n' "$1") | tail -n +3
    return 1
  fi
}

# yq runs from a pinned image, like kubeconform, so it needn't be installed.
# One pin for every suite.
YQ_IMAGE=mikefarah/yq:4.54.3

# Reads a YAML stream on stdin and prints it as one JSON array.
yq_json() {
  docker run --rm -i "$YQ_IMAGE" -o=json ea '[.]'
}

# rendered_page [helm args...]
#   The page the hello chart renders (its ConfigMap's index.html), with any
#   extra helm args, e.g. --set message=...
rendered_page() {
  helm template hello "$PROJECT_DIR/charts/hello" --show-only templates/configmap.yaml "$@" |
    docker run --rm -i "$YQ_IMAGE" '.data["index.html"]'
}
