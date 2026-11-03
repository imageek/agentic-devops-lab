---
name: ship
description: Lint, test, commit, push the current branch and open (or update) a PR. Use when I say ship it, open a PR, or I'm done with a change.
---

# Ship the current branch

1. Refuse if the current branch is `main`; offer to create a feature branch instead.
2. Run `pre-commit run --all-files`, then `make lint test` for every project dir touched (`git diff --name-only main...`).
   If anything fails, fix it if the fix is obvious and in scope; otherwise stop and show me the failure.
3. Show me `git status` and a one-paragraph summary of the diff. Wait for my OK.
4. Commit with a conventional message (`feat:`, `fix:`, `chore:`, `docs:`), scoped to the project number when relevant.
5. `git push`, then `gh pr create --fill` (or `gh pr view --web` if a PR already exists).
6. Run `gh pr checks --watch` and report the CI result.
