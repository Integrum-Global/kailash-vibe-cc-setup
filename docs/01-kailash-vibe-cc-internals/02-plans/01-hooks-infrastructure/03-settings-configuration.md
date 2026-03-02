# Settings Configuration

## CRITICAL: settings.json vs settings.local.json

| File | Purpose | Version Control | Contains |
|------|---------|-----------------|----------|
| `settings.json` | Hooks, shared settings | YES | Hook configurations |
| `settings.local.json` | Permissions, local overrides | NO | User permissions |

**DO NOT MODIFY** `settings.local.json` - it contains user-specific permissions.

## settings.json Configuration

**File Path**: `./.claude/settings.json`

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "scripts/hooks/validate-bash-command.js",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "scripts/hooks/validate-workflow.js",
            "timeout": 10
          },
          {
            "type": "command",
            "command": "scripts/hooks/auto-format.js",
            "timeout": 30
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "scripts/hooks/session-start.js"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "scripts/hooks/session-end.js"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "scripts/hooks/pre-compact.js"
          }
        ]
      }
    ]
  }
}
```

## Hook Configuration Reference

### Hook Structure

```json
{
  "hooks": {
    "[EventName]": [
      {
        "matcher": "[ToolPattern]",  // Optional for tool hooks
        "hooks": [
          {
            "type": "command",
            "command": "[path/to/script]",
            "timeout": [seconds]  // Optional, default varies by event
          }
        ]
      }
    ]
  }
}
```

### Event Names

| Event | Triggers When | Has Matcher | Default Timeout |
|-------|---------------|-------------|-----------------|
| `PreToolUse` | Before tool executes | Yes | 10s |
| `PostToolUse` | After tool completes | Yes | 30s |
| `SessionStart` | Session begins | No | 5s |
| `SessionEnd` | Session ends | No | 10s |
| `PreCompact` | Before compaction | No | 5s |
| `Stop` | Stop signal received | No | 5s |

### Matcher Patterns

The `matcher` field uses regex to match tool names:

| Matcher | Matches |
|---------|---------|
| `Bash` | Only Bash tool |
| `Edit` | Only Edit tool |
| `Write` | Only Write tool |
| `Edit\|Write` | Edit OR Write |
| `.*` | All tools |

### Timeout Guidelines

| Hook Type | Max Timeout | Ideal |
|-----------|-------------|-------|
| PreToolUse | 10s | <1s |
| PostToolUse | 30s | <5s |
| SessionStart | 5s | <2s |
| SessionEnd | 10s | <3s |
| PreCompact | 5s | <2s |

## Exit Codes

| Exit Code | Meaning | Effect |
|-----------|---------|--------|
| 0 | Success | Continue normally |
| 2 | Blocking error | Stop tool execution, show stderr to Claude |
| 1, 3-255 | Non-blocking error | Show warning, continue |

## Validation

After creating settings.json, validate:

```bash
# 1. Syntax check
node -e "JSON.parse(require('fs').readFileSync('.claude/settings.json'))"

# 2. Start Claude with verbose
claude --verbose

# 3. Check hook fires on appropriate action
```

## Troubleshooting

### Hook Not Firing

1. Check file path is correct (relative to project root)
2. Check script is executable: `chmod +x scripts/hooks/*.js`
3. Check matcher pattern matches tool name
4. Run with `claude --verbose` to see hook execution

### Hook Blocking Unexpectedly

1. Check exit code in script (should be 0 for success)
2. Ensure JSON output has `"continue": true`
3. Check stderr for error messages

### Timeout Errors

1. Increase timeout in configuration
2. Optimize hook script (remove unnecessary I/O)
3. Check for infinite loops in script

## Future Expansion

Additional hooks can be added:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "scripts/hooks/validate-bash-command.js", "timeout": 10 }
        ]
      },
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "scripts/hooks/block-random-md.js", "timeout": 5 }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "scripts/hooks/validate-workflow.js", "timeout": 10 },
          { "type": "command", "command": "scripts/hooks/auto-format.js", "timeout": 30 },
          { "type": "command", "command": "scripts/hooks/type-check.js", "timeout": 60 }
        ]
      }
    ]
  }
}
```
