# agentic-devops-lab

DevOps and SRE projects built through **agentic coding** with Claude Code. I set the direction, review, and
own the result; the agent does much of the typing. Each project's README has a *How this was built*
section showing where I steered.

| # | Project | Stack | Status |
|---|---|---|---|
| 01 | [kind-gitops-bootstrap](projects/01-kind-gitops-bootstrap/) | Helm, Ansible, Argo CD, kind, Bash | Done |

## Run any project
```bash
make -C projects/<dir> lint test
```

## Repo conventions
- `CLAUDE.md`: project instructions the agent follows
- `.claude/skills/`: reusable agent workflows (`/new-project`, `/ship`)
- `pre-commit` runs on every commit: shellcheck, YAML syntax, actionlint, gitleaks secret scan
- GitHub Actions gates every PR: the same pre-commit hooks, then `make lint test` for every project
  (yamllint, helm lint, ansible-lint, tests)
