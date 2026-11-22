# Project 02: Bash toolkit, built test-first with bats.
#
#   make lint test   no network or cluster needed (CI runs these)
#
# Run every recipe line in bash with strict mode, same as the scripts.
SHELL := bash
.SHELLFLAGS := -euo pipefail -c

# Targets are commands, not files, so always run them.
.PHONY: lint test up down

# ---------------------------------------------------------------- checks
# shellcheck understands .bats files, so tests get linted too.
# Skipped when there's nothing to check yet.
lint:
	@find . \( -name '*.sh' -o -name '*.bats' \) -exec shellcheck {} +

test:
	@echo "TODO: run bats"

# ---------------------------------------------------------------- lifecycle
# A toolkit of CLI scripts has nothing to start or stop.
up down:
	@echo "$@: nothing to do for a script toolkit"
