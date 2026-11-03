# Learning path

Each project rebuilds something you already did at Broadcom, this time driven by an agent and published
publicly. You already know the domain, so all your attention goes to the agent workflow. Each project
introduces one new agentic pattern.

| # | Project | Agentic pattern you're learning |
|---|---|---|
| 01 | **Bash toolkit**: a cert-expiry checker plus a log-triage script, with bats tests | The basic loop: plan, edit, run tests, fix. Use `/new-project` and `/ship`. Learn to read and reject diffs. |
| 02 | **Helm chart for a Java app** (Tomcat/Corretto) on `kind`, with probes, HPA and a values file per env (us/eu/fedramp) | **Plan mode** (Shift+Tab) for design before code. Make the agent prove it works with `helm lint`, `helm template`, and a smoke test against kind. |
| 03 | **Ansible role + Molecule tests** (patching or hardening), run in Docker | Writing a **custom skill** (`.claude/skills/molecule-test/`) so the agent always tests the same way. |
| 04 | **Terraform GKE module** with `validate` / `plan` only (no apply), plus `trivy config` scanning | Stretching into your weaker area with the agent as tutor. Use **hooks** to auto-run `terraform fmt` after edits. |
| 05 | **GitHub Actions pipeline** replacing a Jenkins pipeline: build, scan and push an image, Helm deploy to kind via `act` | **Subagents**: one writes the pipeline, a separate one reviews it cold. |
| 06 | **MCP server** (Python/uv) exposing read-only kubectl/Prometheus queries to Claude | Extending the agent itself. This is the most in-demand skill on 2026 DevOps job posts. |
| 07 | **ArgoCD GitOps** on kind managing projects 02 and 05 | Long-running multi-session work: keep state in `PLAN.md`, use `/clear` between phases, resume cleanly. |

## Habits to build from day one
- **Context is the budget.** Run `/clear` between unrelated tasks. Put durable facts in CLAUDE.md, not chat.
- **Make the agent verify.** "Done" means lint and tests pass and you've seen the output, not that the agent said so.
- **Review every diff** as if it came from a fast junior engineer.
- **When the agent repeats a mistake,** add one line to CLAUDE.md, or turn the workflow into a skill.
- **Fill in "How this was built"** in each README. Interviewers want to see your judgment, not the agent's typing speed.

## Useful in-session commands
`/init` (generate CLAUDE.md for an existing repo) · `/clear` · `/compact` · `/model` · `/permissions` ·
`/agents` · `/mcp` · `/hooks` · Shift+Tab cycles plan mode and auto-accept · Esc interrupts · Esc Esc rewinds
