---
name: new-project
description: Scaffold a new numbered project under projects/ with README, Makefile, and a feature branch. Use when starting any new lab project.
---

# New project scaffold

1. Ask me for a short name (kebab-case), a one-sentence goal, and the main stack, unless I already gave them.
2. Work out the next number: look at `projects/` and use the highest NN + 1 (zero-padded, starting at 01).
3. Create and switch to branch `feat/NN-short-name` from an up-to-date main.
4. Create `projects/NN-short-name/` with:
   - `README.md` with these sections: Goal, Architecture (short; add a mermaid diagram if useful), Prerequisites,
     Run, Test, Teardown, and How this was built (leave a TODO bullet list).
   - `Makefile` with `.PHONY` targets `lint`, `test`, `up` and `down` (stub with `@echo TODO` where not yet real).
     `lint` must run the linters that fit the stack (shellcheck, yamllint, helm lint, ansible-lint, terraform fmt -check).
5. Add a row to the table in the root `README.md`.
6. Before writing any real implementation, propose a plan (about 3–6 milestones) and wait for my OK.
7. Commit the scaffold with the message `chore(NN): scaffold <short-name>`.
