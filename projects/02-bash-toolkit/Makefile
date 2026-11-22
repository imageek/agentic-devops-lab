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
# The toolkit's commands live in bin/ without an extension, so list them
# explicitly. shellcheck understands .bats files, so tests get linted too.
lint:
	@find bin -type f -exec shellcheck {} +
	@find . \( -name '*.sh' -o -name '*.bats' -o -name '*.bash' \) -exec shellcheck {} +

# bats comes from the system (brew install bats-core); CI pins it to the
# same version in .github/workflows/ci.yml.
test:
	@command -v bats >/dev/null || { echo "bats not found: brew install bats-core" >&2; exit 1; }
	@bats tests

# ---------------------------------------------------------------- lifecycle
# A toolkit of CLI scripts has nothing to start or stop.
up down:
	@echo "$@: nothing to do for a script toolkit"
