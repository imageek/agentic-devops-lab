SHELL := bash
.SHELLFLAGS := -euo pipefail -c

.PHONY: lint test up down

# Each linter is skipped when there's nothing for it to check yet.
# Helm templates aren't plain YAML, so yamllint leaves them to helm lint.
lint:
	@find . -name '*.sh' -exec shellcheck {} +
	@find . \( -name '*.yaml' -o -name '*.yml' \) -not -path '*/templates/*' -exec yamllint {} +
	@find . -name Chart.yaml -exec dirname {} \; | while read -r chart; do helm lint "$$chart"; done
	@if [ -d ansible ]; then ansible-lint ansible; fi

test:
	@echo TODO

up:
	@./scripts/cluster.sh up

down:
	@./scripts/cluster.sh down
