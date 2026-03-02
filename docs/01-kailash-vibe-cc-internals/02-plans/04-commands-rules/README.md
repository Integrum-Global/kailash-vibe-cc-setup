# 04 - Commands and Rules Plan

## Overview

**Priority**: HIGH (Week 2, Days 3-4)
**Impact**: Improve user experience with memorable commands, enforce quality with modular rules

## Current State

### Commands
- **Current**: No commands directory - using numbered skills as commands
- **Issue**: `/01-core-sdk` is not memorable, `/sdk` would be better

### Rules
- **Current**: Rules embedded in `CLAUDE.md` (not modular)
- **Issue**: Cannot enable/disable individual rules, hard to maintain

## What Everything Claude Code Has (That We're Missing)

### Commands (18 files)
```
commands/
├── tdd.md          # TDD workflow
├── plan.md         # Planning workflow
├── code-review.md  # Code review
├── build-fix.md    # Build error fix
├── go-review.md    # Go-specific review
├── learn.md        # Learning commands
├── evolve.md       # Instinct evolution
└── ...
```

### Rules (8 files)
```
rules/
├── security.md     # Security constraints
├── coding-style.md # Code organization
├── testing.md      # Test requirements
├── git-workflow.md # Git conventions
├── agents.md       # Agent orchestration
├── performance.md  # Context management
├── hooks.md        # Hook documentation
└── patterns.md     # Code patterns
```

## Plan Contents

### Commands Layer
- `01-commands-layer.md` - Create memorable command aliases

### Modular Rules
- `02-modular-rules.md` - Extract rules from CLAUDE.md

### Enforcement
- `03-enforcement-hooks.md` - Hook-based rule enforcement

## Files to Create

### Commands (6 files)
```
.claude/commands/
├── sdk.md          # → /01-core-sdk
├── db.md           # → /02-dataflow
├── api.md          # → /03-nexus
├── ai.md           # → /04-kaizen
├── test.md         # → /12-testing-strategies
└── validate.md     # → /17-gold-standards
```

### Rules (5 files)
```
.claude/rules/
├── agents.md       # Mandatory delegations (already planned)
├── security.md     # Security constraints
├── testing.md      # Test requirements
├── patterns.md     # Kailash patterns
└── git.md          # Git workflow
```

## Success Criteria

| Metric | Current | Target |
|--------|---------|--------|
| Memorable commands | 0 | 6+ |
| Modular rule files | 0 | 5 |
| Rule enforcement | Manual | Hook-assisted |
