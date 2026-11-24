# Project 01: kind cluster + Argo CD, bootstrapped by Ansible, then driven by Git.
#
#   make lint test   no cluster needed (CI runs these)
#   make up          create kind-lab, install Argo CD, apply the root app
#   make smoke       check the running cluster
#   make down        delete kind-lab
#
# Run every recipe line in bash with strict mode, same as the scripts.
SHELL := bash
.SHELLFLAGS := -euo pipefail -c

# ---------------------------------------------------------------- settings
# Use the pinned collections, whichever Python ansible and ansible-lint run on.
export ANSIBLE_COLLECTIONS_PATH := $(CURDIR)/.collections

# Marker file: make reinstalls collections only when requirements.yml is newer.
COLLECTIONS_STAMP := .collections/.installed

# Git revision Argo CD syncs from. Set it to a branch to test before merging:
#   make up GITOPS_REVISION=feat/my-branch
GITOPS_REVISION ?=

# Read from kind-config.yaml so the cluster and kubeconform can't drift apart.
KUBERNETES_VERSION := $(shell sed -n 's|.*kindest/node:v\([0-9.]*\)@.*|\1|p' kind-config.yaml)
ifeq ($(KUBERNETES_VERSION),)
$(error could not read the kindest/node version from kind-config.yaml)
endif
# Run kubeconform from its pinned image, so it needn't be installed locally.
KUBECONFORM := docker run --rm -i ghcr.io/yannh/kubeconform:v0.8.0

# Targets are commands, not files, so always run them.
.PHONY: lint test smoke up down

# ---------------------------------------------------------------- setup
# --force because galaxy otherwise counts a copy bundled with ansible as
# installed, and ansible-lint may not be able to see that copy.
$(COLLECTIONS_STAMP): ansible/requirements.yml
	@ansible-galaxy collection install --force -r $< -p .collections >/dev/null
	@touch $@

# ---------------------------------------------------------------- checks
# Each linter is skipped when there's nothing for it to check yet.
# Helm templates aren't plain YAML, so yamllint leaves them to helm lint.
lint: $(COLLECTIONS_STAMP)
	@find . -name .collections -prune -o \( -name '*.sh' -o -name '*.bats' -o -name '*.bash' \) -exec shellcheck {} +
	@find . -name .collections -prune -o \( -name '*.yaml' -o -name '*.yml' \) -not -path '*/templates/*' -exec yamllint {} +
	@find . -name .collections -prune -o -name Chart.yaml -exec dirname {} \; | while read -r chart; do helm lint "$$chart"; done
	@ansible-lint ansible

# No cluster needed. Argo CD Applications have no bundled schema, so kubeconform
# skips them; their schema is only checked by the API server on a live cluster.
# Order: playbook syntax, then the bats suites in tests/ (bats doesn't descend
# into tests/smoke/, which needs a cluster), then render both charts and
# validate the manifests.
# bats comes from the system (brew install bats-core); CI pins its version.
test: $(COLLECTIONS_STAMP)
	@command -v bats >/dev/null || { echo "bats not found: brew install bats-core" >&2; exit 1; }
	@ansible-playbook -i ansible/inventory.yml ansible/bootstrap.yml --syntax-check
	@bats tests
	@for chart in charts/*/; do helm template test "$$chart"; done | $(KUBECONFORM) -strict -summary -ignore-missing-schemas -kubernetes-version $(KUBERNETES_VERSION)

# Needs a running cluster, so it's separate from test.
smoke:
	@./scripts/smoke.sh

# ---------------------------------------------------------------- lifecycle
# Safe to re-run: the cluster step skips an existing cluster, and the playbook
# only changes what differs. GITOPS_REVISION is passed only when set, so the
# playbook's default (main) applies otherwise.
up: $(COLLECTIONS_STAMP)
	@./scripts/cluster.sh up
	@ansible-playbook -i ansible/inventory.yml ansible/bootstrap.yml $(if $(GITOPS_REVISION),-e gitops_revision=$(GITOPS_REVISION))

# Deletes only kind-lab (the name is fixed in cluster.sh).
down:
	@./scripts/cluster.sh down
