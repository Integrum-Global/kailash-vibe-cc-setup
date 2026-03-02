# 01 - Hooks Infrastructure Plan

## Overview

**Priority**: CRITICAL (Week 1, Days 1-2)
**Status**: Not Implemented (0/6 hook types)
**Impact**: Enables ALL automation - formatting, validation, session persistence, learning

## Why Hooks Are Critical

Without hooks, Kailash relies 100% on LLM decisions which have:
- 70-80% reliability (vs 100% for hooks)
- No automatic formatting
- No input validation
- No session persistence
- No learning observation

Everything Claude Code has **6 hook types** with **169 lines** of configuration. Kailash has **none**.

## Hook Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     SESSION LIFECYCLE                        │
│                                                             │
│  SessionStart ─────► [Work] ─────► SessionEnd               │
│       │                │                │                    │
│       ▼                ▼                ▼                    │
│  Load State      PreToolUse        Save State               │
│                       │                                      │
│                       ▼                                      │
│                  Tool Execute                               │
│                       │                                      │
│                       ▼                                      │
│                  PostToolUse                                │
│                       │                                      │
│                       ▼                                      │
│               [More Tools...]                               │
│                       │                                      │
│                       ▼                                      │
│                  PreCompact                                 │
│                       │                                      │
│                       ▼                                      │
│               Context Compaction                            │
└─────────────────────────────────────────────────────────────┘
```

## Files to Create

| File | Purpose | Priority |
|------|---------|----------|
| `scripts/hooks/validate-bash-command.js` | Block dangerous commands | CRITICAL |
| `scripts/hooks/validate-workflow.js` | Enforce Kailash patterns | CRITICAL |
| `scripts/hooks/auto-format.js` | Format Python/JS/TS | HIGH |
| `scripts/hooks/session-start.js` | Load previous state | HIGH |
| `scripts/hooks/session-end.js` | Persist current state | HIGH |
| `scripts/hooks/pre-compact.js` | Save context before compaction | MEDIUM |
| `.claude/settings.json` | Hook configuration | CRITICAL |

## Implementation Details

See individual files:
- `01-directory-structure.md` - Create required directories
- `02-hook-scripts.md` - Complete hook script implementations
- `03-settings-configuration.md` - settings.json configuration
- `04-testing-validation.md` - How to test each hook

## Dependencies

- Node.js (for cross-platform hook scripts)
- Optional: `black` for Python formatting
- Optional: `prettier` for JS/TS formatting

## Success Criteria

| Test | Expected Result |
|------|-----------------|
| Start session with `--verbose` | "SessionStart hook fired" |
| Run bash command | "PreToolUse hook fired for Bash" |
| Edit Python file | File auto-formatted by black |
| Exit session | State saved to ~/.claude/sessions/ |
| Resume session | Previous state loaded |
| Compact context | Critical state preserved |

## Rollback

```bash
# If hooks break sessions
mv .claude/settings.json .claude/settings.json.disabled
# Sessions will work without hooks
```
