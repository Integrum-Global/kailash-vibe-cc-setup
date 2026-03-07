---
name: sync-kailash
description: "Pull and sync latest kailash-coc-claude-py template updates"
---

Pull the latest updates from the kailash-coc-claude-py upstream repository and sync them into this project.

## Steps

1. **Run the sync script:**
   ```bash
   ./sync-kailash.sh --pull --apply
   ```

2. **Review what changed** in the output

3. **Handle CLAUDE.md differences:**
   - If CLAUDE.md differs, show the diff between `kailash-setup/CLAUDE.md` and `CLAUDE.md`
   - Help merge relevant upstream changes into the project CLAUDE.md
   - Preserve project-specific customizations

4. **Read changed files to understand updates:**
   - Read files in `.claude/agents/`, `.claude/rules/`, `.claude/skills/`
   - Read updated hook scripts in `scripts/hooks/`
   - Understand what new capabilities or changes were added

5. **Summarize updates to the user:**
   - What changed (agents, commands, skills, hooks, guides)
   - What new features or capabilities are available
   - Any breaking changes or important notices

6. **Commit all synced files:**
   ```bash
   git add -A
   git commit -m "chore: sync kailash-setup upstream updates"
   ```

7. **Determine if restart is needed:**
   - Session restart required if: CLAUDE.md, .claude/settings.json, or .claude/rules/ changed
   - Tell the user clearly whether they need to restart

## Error Handling

- If sync script doesn't exist: Explain that `/setup` needs to be run first
- If uncommitted changes block the sync: Ask user to commit or stash first
- If merge conflicts in CLAUDE.md: Guide user through resolution
