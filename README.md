# agentic-devops-lab

[![ci](https://github.com/imageek/agentic-devops-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/imageek/agentic-devops-lab/actions/workflows/ci.yml)

I'm a DevOps and site reliability engineer with 25+ years in infrastructure and systems engineering:
Ansible, Kubernetes, Helm, Jenkins, GCP, 24x7 on-call and incident response, Vault, OIDC and TLS.

This repo is where I learn **agentic coding** with Claude Code, on problems I already know well. I set the
direction, review every diff, and own the result; the agent does much of the typing. Each project's README
has a *How this was built* section showing what the agent did and where I steered.

Every project is reproducible from source control, runs locally (kind, mocks, `terraform plan` only), and
must pass lint and tests in CI before it merges.

| # | Project | Stack | Status |
|---|---|---|---|
| 01 | [kind-gitops-bootstrap](projects/01-kind-gitops-bootstrap/) | Helm, Ansible, Argo CD, kind, Bash | Done |
| 02 | [bash-toolkit](projects/02-bash-toolkit/) | Bash, bats, Make, pre-commit | Done |

What's next: [learning path](docs/learning-path.md).

GitHub is the primary copy; PRs and merges happen here. Every merge to `main` is mirrored to
[GitLab](https://gitlab.com/imageek72/agentic-devops-lab).

## Run any project
```bash
make -C projects/<dir> lint test
```

## Repo conventions
- `CLAUDE.md`: project instructions the agent follows
- `.claude/skills/`: reusable agent workflows (`/new-project`, `/ship`)
- `pre-commit` runs on every commit: shellcheck, YAML syntax, actionlint, gitleaks secret scan
- GitHub Actions gates every PR: the same pre-commit hooks, then `make lint test` for every project
  (yamllint, helm lint, ansible-lint, bats and other tests), and an end-to-end job that installs project
  01's chart on a throwaway kind cluster and tests the running pods

## License
[MIT](LICENSE)
