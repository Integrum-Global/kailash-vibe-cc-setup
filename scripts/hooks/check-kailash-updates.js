#!/usr/bin/env node
/**
 * SessionStart hook: Check if kailash-setup subtree has upstream updates available.
 * Does NOT auto-sync — just notifies the user so they can run ./sync-kailash.sh
 */

const { execSync } = require("child_process");
const path = require("path");

const projectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const subtreeDir = path.join(projectDir, "kailash-setup");
const fs = require("fs");

// Skip if subtree doesn't exist
if (!fs.existsSync(subtreeDir)) {
  process.exit(0);
}

try {
  // Fetch latest from upstream (quiet, no merge)
  execSync(
    "git fetch https://github.com/Integrum-Global/kailash-coc-claude-py.git main --quiet",
    { cwd: projectDir, timeout: 15000, stdio: "pipe" }
  );

  // Check if FETCH_HEAD differs from what we have in the subtree
  const fetchHead = execSync("git rev-parse FETCH_HEAD", {
    cwd: projectDir,
    encoding: "utf-8",
    stdio: "pipe",
  }).trim();

  // Get the last subtree merge commit
  const subtreeLog = execSync(
    'git log --oneline --all --grep="kailash-setup" -1 --format="%H"',
    { cwd: projectDir, encoding: "utf-8", stdio: "pipe" }
  ).trim();

  if (fetchHead && subtreeLog) {
    // Check if there are new commits upstream since our last pull
    const behindCount = execSync(
      `git rev-list --count ${subtreeLog}..FETCH_HEAD 2>/dev/null || echo "0"`,
      { cwd: projectDir, encoding: "utf-8", stdio: "pipe" }
    ).trim();

    const count = parseInt(behindCount, 10);
    if (count > 0) {
      console.log(
        JSON.stringify({
          result: "warn",
          message: [
            `Kailash COC template has ${count} upstream update(s) available.`,
            ``,
            `ACTION REQUIRED — Do the following BEFORE starting any other work:`,
            `1. Run: ./sync-kailash.sh --pull --apply`,
            `2. Read the changed files in .claude/agents/, .claude/rules/, .claude/skills/, and scripts/hooks/ to understand what is new`,
            `3. Summarize the updates to the user: what changed, what new capabilities are available, and whether a session restart is needed`,
            `4. Commit the synced files with: chore: sync kailash-setup upstream updates`,
            `5. A restart is needed if CLAUDE.md, .claude/settings.json, or .claude/rules/ changed`,
          ].join("\n"),
        })
      );
      process.exit(0);
    }
  }

  // Up to date or couldn't determine — silent success
  console.log(JSON.stringify({ result: "success", message: "" }));
} catch (err) {
  // Network errors, git errors — don't block the session, just skip
  console.log(JSON.stringify({ result: "success", message: "" }));
}
