# Everything Claude Code - Hooks Deep Analysis

## Hook Architecture

Hooks in Claude Code are event-driven triggers that execute shell commands or prompts at specific lifecycle points. They provide **deterministic automation** that doesn't rely on LLM decisions.

## Hook Lifecycle (Complete)

```
SessionStart
    ↓
UserPromptSubmit
    ↓
PreToolUse → PermissionRequest → PostToolUse → PostToolUseFailure
    ↓
SubagentStart → SubagentStop
    ↓
Stop
    ↓
PreCompact
    ↓
SessionEnd
```

## Hooks Defined in Repository

**File**: `hooks/hooks.json` (169 lines)

### PreToolUse Hooks

#### 1. Block Dev Servers Outside Tmux
```json
{
  "matcher": "Bash",
  "hooks": [{
    "type": "command",
    "command": "block-dev-servers-outside-tmux.sh"
  }]
}
```
**Purpose**: Prevent dev server launches without tmux (long-running process management)

#### 2. Suggest Tmux for Long Commands
```json
{
  "matcher": "Bash",
  "hooks": [{
    "type": "command",
    "command": "suggest-tmux.sh"
  }]
}
```
**Triggers on**: npm, pnpm, yarn, cargo, pytest
**Purpose**: Remind user about tmux for long-running commands

#### 3. Git Push Review
```json
{
  "matcher": "Bash",
  "hooks": [{
    "type": "command",
    "command": "review-before-push.sh"
  }]
}
```
**Purpose**: Final review reminder before pushing to remote

#### 4. Block Random MD Files
```json
{
  "matcher": "Write",
  "hooks": [{
    "type": "command",
    "command": "block-md-creation.sh"
  }]
}
```
**Purpose**: Prevent unnecessary markdown/txt file creation

### PostToolUse Hooks

#### 1. PR Creation Feedback
```json
{
  "matcher": "Bash",
  "hooks": [{
    "type": "command",
    "command": "pr-feedback.sh"
  }]
}
```
**Purpose**: Log PR creation, suggest review commands

#### 2. Prettier Formatting (JS/TS)
```json
{
  "matcher": "Edit|Write",
  "hooks": [{
    "type": "command",
    "command": "prettier-format.sh"
  }]
}
```
**File Filter**: `*.js`, `*.ts`, `*.jsx`, `*.tsx`
**Purpose**: Auto-format JavaScript/TypeScript files

#### 3. TypeScript Type Checking
```json
{
  "matcher": "Edit",
  "hooks": [{
    "type": "command",
    "command": "tsc-check.sh"
  }]
}
```
**File Filter**: `*.ts`, `*.tsx`
**Purpose**: Run TypeScript compiler after edits

#### 4. Console.log Warning
```json
{
  "matcher": "Edit|Write",
  "hooks": [{
    "type": "command",
    "command": "console-log-warn.sh"
  }]
}
```
**Purpose**: Warn about debug console.log statements

### Stop Hooks

#### Console.log Audit
```json
{
  "hooks": [{
    "type": "command",
    "command": "check-console-log.js"
  }]
}
```
**Purpose**: Final audit for console.log in modified files at session end

### SessionStart Hooks

#### Context Loading
**Script**: `scripts/hooks/session-start.js`

**Purpose**:
- Load previous session context
- Detect package manager
- Restore state from last session

### PreCompact Hooks

#### State Persistence
**Script**: `scripts/hooks/pre-compact.js`

**Purpose**: Save current state before context compaction to prevent loss

### SessionEnd Hooks

#### Pattern Extraction
**Script**: `scripts/hooks/session-end.js`

**Purpose**:
- Persist learnings
- Export patterns discovered
- Update continuous learning system

## Hook Scripts (Node.js Cross-Platform)

Located in `scripts/hooks/`:

| Script | Event | Purpose |
|--------|-------|---------|
| `session-start.js` | SessionStart | Load context |
| `session-end.js` | SessionEnd | Save state |
| `pre-compact.js` | PreCompact | Pre-compaction save |
| `suggest-compact.js` | Various | Compaction suggestions |
| `evaluate-session.js` | SessionEnd | Pattern extraction |
| `check-console-log.js` | Stop | Console.log detection |

## Hook Configuration Patterns

### Exit Code Semantics

| Exit Code | Meaning | Behavior |
|-----------|---------|----------|
| 0 | Success | Continue (stdout shown in verbose) |
| 2 | Blocking Error | Tool call blocked, stderr fed to Claude |
| Other | Non-blocking Error | stderr shown to user, continue |

### Hook Input (stdin JSON)

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/dir",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": "npm run dev" }
}
```

### Hook Output (stdout JSON)

```json
{
  "continue": true,
  "stopReason": "Optional stop message",
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|ask",
    "permissionDecisionReason": "Explanation",
    "updatedInput": { "modified_field": "new_value" },
    "additionalContext": "Context for Claude"
  }
}
```

## Advanced Patterns

### Input Validation Hook
```bash
#!/bin/bash
# Validate readonly queries - block writes
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
if echo "$COMMAND" | grep -iE '(INSERT|UPDATE|DELETE)' > /dev/null; then
  echo "Write operations blocked" >&2
  exit 2
fi
exit 0
```

### Prompt-Based Hooks (Stop/SubagentStop only)
```json
{
  "type": "prompt",
  "prompt": "Should Claude continue working? Check if tasks are complete. Respond: {\"ok\": true} or {\"ok\": false, \"reason\": \"...\"}"
}
```

### TypeScript Auto-Format Example
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{
          "type": "command",
          "command": "jq -r '.tool_input.file_path' | { read f; if [[ \"$f\" == *.ts ]]; then npx prettier --write \"$f\"; fi; }"
        }]
      }
    ]
  }
}
```

## Integration with Continuous Learning v2

The hooks system powers the v2 learning system:

```
PreToolUse  →  Log to observations.jsonl
PostToolUse →  Log result to observations.jsonl
SessionEnd  →  Trigger Observer Agent analysis
```

**Reliability**: 100% - Every tool call is captured (vs v1's 50-80% reliability)

## Gap Analysis

### Strengths
1. Comprehensive lifecycle coverage
2. Cross-platform Node.js scripts
3. Integration with continuous learning
4. Sophisticated exit code handling
5. Input/output modification capability

### Missing
1. No SubagentStart hooks defined (event exists but unused)
2. No PermissionRequest hooks
3. No UserPromptSubmit hooks (context injection opportunity)
4. Limited PostToolUseFailure handling
5. No hook testing framework
