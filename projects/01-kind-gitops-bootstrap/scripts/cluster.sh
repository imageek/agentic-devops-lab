#!/usr/bin/env bash
# Create or delete the local kind cluster for this project.
#
# The cluster name is a constant, not an argument or env var, so this script
# can only ever act on kind-lab.
set -euo pipefail

readonly CLUSTER_NAME="lab"
readonly CONTEXT="kind-${CLUSTER_NAME}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROJECT_DIR

# Usage errors exit 2, the usual code for "called wrong" (vs 1 for "failed").
usage() {
  echo "usage: ${0##*/} up|down" >&2
}

# Exact whole-line match (-x), so a cluster named e.g. "lab2" doesn't count.
cluster_exists() {
  local clusters
  clusters="$(kind get clusters 2>/dev/null)"
  grep -qx "${CLUSTER_NAME}" <<<"${clusters}"
}

# kind create switches the current context to the new cluster. Put back
# whatever was selected, so a bare kubectl keeps pointing where it did.
restore_context() {
  local previous="$1"
  if [[ -n "${previous}" ]]; then
    kubectl config use-context "${previous}" >/dev/null
  fi
}

# Create the cluster if it's missing (safe to re-run), then show its nodes.
# --wait blocks until the control plane is Ready.
up() {
  if cluster_exists; then
    echo "cluster ${CLUSTER_NAME} already exists"
  else
    local previous
    previous="$(kubectl config current-context 2>/dev/null || true)"
    kind create cluster \
      --name "${CLUSTER_NAME}" \
      --config "${PROJECT_DIR}/kind-config.yaml" \
      --wait 120s
    restore_context "${previous}"
  fi
  kubectl --context "${CONTEXT}" get nodes
}

# --name is always passed, so kind never falls back to KIND_CLUSTER_NAME
# (tests/cluster.bats checks this).
down() {
  kind delete cluster --name "${CLUSTER_NAME}"
}

main() {
  if [[ $# -ne 1 ]]; then
    usage
    exit 2
  fi
  case "$1" in
    up) up ;;
    down) down ;;
    *)
      usage
      exit 2
      ;;
  esac
}

main "$@"
