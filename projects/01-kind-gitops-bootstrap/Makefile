SHELL := bash
.SHELLFLAGS := -euo pipefail -c

# Use the pinned collections, whichever Python ansible and ansible-lint run on.
export ANSIBLE_COLLECTIONS_PATH := $(CURDIR)/.collections

COLLECTIONS_STAMP := .collections/.installed

# Git revision Argo CD syncs from. Set it to a branch to test before merging:
#   make up GITOPS_REVISION=feat/my-branch
GITOPS_REVISION ?=

.PHONY: lint test up down

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

test:
	@echo TODO

up: $(COLLECTIONS_STAMP)
	@./scripts/cluster.sh up
	@ansible-playbook -i ansible/inventory.yml ansible/bootstrap.yml $(if $(GITOPS_REVISION),-e gitops_revision=$(GITOPS_REVISION))

down:
	@./scripts/cluster.sh down
