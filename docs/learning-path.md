# Learning path

Each project rebuilds something I've done in my career, this time driven by an agent and published in
the open. I already know the domain, so my attention goes to the agent workflow. Each project introduces
one new agentic pattern, and each one ships with tests that suit its stack.

Where I can, the projects run against real things I operate rather than toy examples: my monitoring
cluster, and the self-hosted media services on my home Linux server.

| # | Project | Testing | Agentic pattern |
|---|---|---|---|
| 01 | **[kind + Argo CD GitOps bootstrap](../projects/01-kind-gitops-bootstrap/)** ✅ | fake binaries, kubeconform, live smoke test | The basic loop: plan, edit, test, fix. `/new-project` and `/ship`; reading and rejecting diffs. |
| 02 | **Bash toolkit:** a cert-expiry checker and a log-triage script. Also move project 01's script tests onto bats. | **bats**, written before the code | **Test-first** with the agent: failing tests define "done". |
| 03 | **Monitoring under GitOps:** the Argo CD hub in `kind-lab` takes over `kind-multi` and rebuilds Prometheus and Grafana from Git, with dashboards as code. | helm-unittest, smoke test | **Plan mode** for the design: hub and spoke across clusters, and rebuild instead of adopt. |
| 04 | **Secrets:** SOPS + age for encrypted secrets in the repo; Vault + External Secrets in the cluster. SOPS delivers the bootstrap secret, Vault holds the rest. | a check that every secret file is encrypted | **Hooks:** block the agent from reading decrypted secrets, and refuse commits of unencrypted ones. |
| 05 | **Helm chart for a Java app** (Tomcat/Corretto): probes, HPA, a values file per environment, secrets from Vault. | helm-unittest | **Custom skill** (`chart-test`) so every chart is tested the same way. |
| 06 | **Ansible role:** harden my Linux server and install k3s on it. | **Molecule** | **Custom skill** (`molecule-test`). |
| 07 | **Home server migration:** move radarr, sonarr and prowlarr from Docker Compose to k3s, deployed by Argo CD: persistent config, media mounts, API keys in Vault, a cutover plan and a rollback. | smoke checks, a rollback drill | **Long-running work across sessions:** state in `PLAN.md`, `/clear` between phases, resume cleanly. |
| 08 | **Terraform GKE module:** `validate` and `plan` only, never `apply`; `trivy config` scanning. | `terraform test` | **Agent as tutor** in my weaker area. |
| 09 | **CI pipeline replacing a Jenkins pipeline:** build, scan and push an image, then deploy with Helm. Built twice: **GitHub Actions** and **GitLab CI**. | `act` runs it locally | **Subagents:** one writes the pipeline, a second reviews it cold. |
| 10 | **MCP server** (Python/uv): read-only kubectl and Prometheus queries against project 03's stack. | pytest | **Extending the agent** itself. |

Order matters: 04 comes before 05 and 07 so they can use Vault; 06 builds the server 07 runs on; 10
queries the monitoring stack from 03.

## Ground rules
- Nothing needs real cloud credentials to pass `make test`.
- `kind-multi` and the home server are real systems I use. A project may touch them only once its plan
  says so, and the rule in `CLAUDE.md` changes in that project's PR, not before.
- Nothing about my home network goes in this public repo: no IPs, hostnames, or API keys. Secrets are
  encrypted (SOPS) or live in Vault.
- GitHub is the primary copy; every merge to `main` is mirrored to
  [GitLab](https://gitlab.com/imageek72/agentic-devops-lab).

## Habits
- **Context is the budget.** `/clear` between unrelated tasks. Durable facts go in `CLAUDE.md`, not chat.
- **Make the agent verify.** "Done" means lint and tests pass and I've seen the output, not that the
  agent said so.
- **Review every diff** as if it came from a fast junior engineer.
- **When the agent repeats a mistake,** add one line to `CLAUDE.md`, or turn the workflow into a skill.
- **Fill in "How this was built"** in each README: what the agent did, what I steered, and what review
  caught.

## Useful in-session commands
`/init` (generate CLAUDE.md for an existing repo) · `/clear` · `/compact` · `/model` · `/permissions` ·
`/agents` · `/mcp` · `/hooks` · Shift+Tab cycles plan mode and auto-accept · Esc interrupts · Esc Esc rewinds
