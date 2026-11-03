# agentic-devops-lab

Monorepo of self-contained DevOps projects, built with Claude Code. Doubles as a public portfolio.

## Layout
- `projects/NN-short-name/`: one project per folder, numbered in the order built. Each one is self-contained:
  README.md, Makefile, its own tests, no cross-project imports.
- `docs/`: learning path and notes on agentic patterns I've picked up.
- `.claude/skills/`: repo-level skills (`/new-project`, `/ship`).

## Every project must have
- `README.md`: what / why / run / test / teardown, plus a "How this was built" section noting
  what the agent did vs what I steered (that's the portfolio value).
- `Makefile` with at least `make lint`, `make test`, `make up`, `make down` (where applicable).
- Nothing that needs real cloud credentials to pass `make test`. Use kind, LocalStack, mocks, `terraform validate`/`plan` only.

## Commands
- Lint everything: `pre-commit run --all-files`
- One project: `make -C projects/<dir> lint test`

## Workflow
- Branch per project or feature: `feat/NN-short-name`. PR into main via `gh pr create`; CI must pass.
- Local k8s: `kind create cluster --name lab` (Docker via colima must be running).
