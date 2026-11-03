SHELL := bash
.SHELLFLAGS := -euo pipefail -c

# Use the pinned collections, whichever Python ansible and ansible-lint run on.
export ANSIBLE_COLLECTIONS_PATH := $(CURDIR)/.collections

COLLECTIONS_STAMP := .collections/.installed

# Git revision Argo CD syncs from. Set it to a branch to test before merging:
#   make up GITOPS_REVISION=feat/my-branch
GITOPS_REVISION ?=

KUBERNETES_VERSION := 1.37.0
KUBECONFORM := docker run --rm -i ghcr.io/yannh/kubeconform:v0.8.0

.PHONY: lint test smoke up down

# --force because galaxy otherwise counts a copy bundled with ansible as
# installed, and ansible-lint may not be able to see that copy.
$(COLLECTIONS_STAMP): ansible/requirements.yml
	@ansible-galaxy collection install --force -r $< -p .collections >/dev/null
	@touch $@

# Each linter is skipped when there's nothing for it to check yet.
# Helm templates aren't plain YAML, so yamllint leaves them to helm lint.
lint: $(COLLECTIONS_STAMP)
	@find . -name .collections -prune -o -name '*.sh' -exec shellcheck {} +
	@find . -name .collections -prune -o \( -name '*.yaml' -o -name '*.yml' \) -not -path '*/templates/*' -exec yamllint {} +
	@find . -name .collections -prune -o -name Chart.yaml -exec dirname {} \; | while read -r chart; do helm lint "$$chart"; done
	@ansible-lint ansible

# No cluster needed. Argo CD Applications have no bundled schema, so kubeconform
# skips them; their schema is only checked by the API server on a live cluster.
test: $(COLLECTIONS_STAMP)
	@./tests/test_cluster.sh
	@ansible-playbook -i ansible/inventory.yml ansible/bootstrap.yml --syntax-check
	@./tests/test_playbook_guard.sh
	@for chart in charts/*/; do helm template test "$$chart"; done | $(KUBECONFORM) -strict -summary -ignore-missing-schemas -kubernetes-version $(KUBERNETES_VERSION)

# Needs a running cluster, so it's separate from test.
smoke:
	@./scripts/smoke.sh

up: $(COLLECTIONS_STAMP)
	@./scripts/cluster.sh up
	@ansible-playbook -i ansible/inventory.yml ansible/bootstrap.yml $(if $(GITOPS_REVISION),-e gitops_revision=$(GITOPS_REVISION))

down:
	@./scripts/cluster.sh down
