---
name: setup
description: "Initial project setup after cloning kailash-coc-claude-py template"
---

Set up a newly cloned kailash-coc-claude-py template for a new project.

**IMPORTANT:** This command should only be run ONCE after cloning the template. Do not run on existing projects.

## Steps

### 1. Verify this is a fresh clone
Check that:
- `kailash-setup/` directory does NOT exist (if it does, setup already ran)
- `.git/` exists (this is a git repo)
- `.claude/agents/` exists (this is the kailash template)

If any check fails, warn the user and stop.

### 2. Add upstream subtree
Run:
```bash
git subtree add --prefix=kailash-setup https://github.com/Integrum-Global/kailash-coc-claude-py.git main --squash
```

This creates `kailash-setup/` as a subtree tracking the upstream template.

### 3. Verify sync workflow is present
Check that:
- `sync-kailash.sh` exists at project root
- `scripts/hooks/check-kailash-updates.js` exists
- `.claude/settings.json` has the check-kailash-updates hook in SessionStart

If missing, explain what's wrong and suggest manual setup.

### 4. Commit everything
Run:
```bash
git add -A
git commit -m "chore: initial project setup from kailash-coc-claude-py template

- Added kailash-setup subtree for upstream template updates
- Sync workflow ready: /sync-kailash or ./sync-kailash.sh --pull --apply"
```

### 5. Show status and next steps
Display:
```
Setup complete! Infrastructure is ready.

Next steps:
1. Start analysis to understand what you're building:
   /analyze

2. After analysis, customize CLAUDE.md with project-specific details

3. To pull template updates later:
   /sync-kailash
   (or manually: ./sync-kailash.sh --pull --apply)

The SessionStart hook will automatically notify you when upstream updates are available.
```

## Error Handling

- If `kailash-setup/` already exists: "Setup already ran. Use /sync-kailash instead."
- If git operations fail: Show the error, suggest manual setup
- If Node.js is not available for settings.json update: Warn but continue
- If working tree has uncommitted changes: Warn and ask user to commit first
