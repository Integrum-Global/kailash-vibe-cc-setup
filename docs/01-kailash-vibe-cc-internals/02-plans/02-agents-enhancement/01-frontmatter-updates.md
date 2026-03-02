# Agent Frontmatter Updates

## Why Frontmatter Matters

The frontmatter (YAML block at top of agent file) tells Claude Code:
- **name**: How to reference the agent
- **description**: When to use it (triggers auto-delegation)
- **tools**: What tools the agent can use (SECURITY)
- **model**: Which model to use (cost/capability tradeoff)

Without `tools:` and `model:`, Claude Code doesn't know:
1. What capabilities the agent has
2. Whether to use a cheaper model for simple tasks

## Frontmatter Template

```yaml
---
name: agent-name
description: [Role] specialist. Use when [trigger condition]. (max 120 chars)
tools: Read, Write, Edit, Bash, Grep, Glob, Task
model: opus
---
```

## Tool Selection by Agent Type

| Agent Type | Tools | Rationale |
|------------|-------|-----------|
| Analysis/Planning | Read, Grep, Glob | Read-only, no side effects |
| Implementation | Read, Write, Edit, Bash, Grep, Glob, Task | Full access for coding |
| Review | Read, Grep, Glob | Read-only for safety |
| Specialist | Read, Write, Edit, Bash, Grep, Glob, Task | Full access needed |

## Model Selection by Task Complexity

| Complexity | Model | Example Agents |
|------------|-------|----------------|
| High (reasoning, multi-step) | opus | deep-analyst, framework-advisor |
| Medium (code generation) | opus or sonnet | pattern-expert, tdd-implementer |
| Simple (validation, lookup) | sonnet | gold-standards-validator |
| Very simple (task management) | haiku | todo-manager |

## Agent-by-Agent Update Plan

### Root-Level Agents (7)

| Agent | tools | model | Notes |
|-------|-------|-------|-------|
| `deep-analyst.md` | Read, Grep, Glob | opus | Analysis only |
| `requirements-analyst.md` | Read, Write, Edit, Grep, Glob | opus | Creates ADRs |
| `sdk-navigator.md` | Read, Grep, Glob | sonnet | Documentation lookup |
| `framework-advisor.md` | Read, Grep, Glob, Task | opus | Delegates to specialists |
| `pattern-expert.md` | Read, Write, Edit, Bash, Grep, Glob | opus | Implementation |
| `tdd-implementer.md` | Read, Write, Edit, Bash, Grep, Glob | opus | Test-first coding |
| `intermediate-reviewer.md` | Read, Grep, Glob | sonnet | Code review |

### Framework Specialists (4)

| Agent | tools | model | Notes |
|-------|-------|-------|-------|
| `dataflow-specialist.md` | Read, Write, Edit, Bash, Grep, Glob, Task | opus | Full implementation |
| `nexus-specialist.md` | Read, Write, Edit, Bash, Grep, Glob, Task | opus | Full implementation |
| `kaizen-specialist.md` | Read, Write, Edit, Bash, Grep, Glob, Task | opus | Full implementation |
| `mcp-specialist.md` | Read, Write, Edit, Bash, Grep, Glob, Task | opus | Full implementation |

### Frontend Specialists (4)

| Agent | tools | model | Notes |
|-------|-------|-------|-------|
| `flutter-specialist.md` | Read, Write, Edit, Bash, Grep, Glob | opus | Full implementation |
| `react-specialist.md` | Read, Write, Edit, Bash, Grep, Glob | opus | Full implementation |
| `frontend-developer.md` | Read, Write, Edit, Bash, Grep, Glob | opus | Full implementation |
| `uiux-designer.md` | Read, Grep, Glob | opus | Design analysis |

### Management Agents (3)

| Agent | tools | model | Notes |
|-------|-------|-------|-------|
| `todo-manager.md` | Read, Write, Grep, Glob | haiku | Simple task ops |
| `gh-manager.md` | Read, Write, Bash, Grep, Glob | sonnet | GitHub operations |
| `git-release-specialist.md` | Read, Write, Bash, Grep, Glob | sonnet | Git operations |

### Other Agents

| Agent | tools | model | Notes |
|-------|-------|-------|-------|
| `gold-standards-validator.md` | Read, Grep, Glob | sonnet | Validation only |
| `testing-specialist.md` | Read, Write, Edit, Bash, Grep, Glob | opus | Test creation |
| `documentation-validator.md` | Read, Bash, Grep, Glob | sonnet | Doc testing |
| `deployment-specialist.md` | Read, Write, Bash, Grep, Glob | opus | Deployment ops |

## Example: Before and After

### Before (Current)
```yaml
---
name: dataflow-specialist
description: Database operations specialist for Kailash DataFlow framework
---
```

### After (Updated)
```yaml
---
name: dataflow-specialist
description: DataFlow v0.10.15+ specialist. Use for database operations, model definitions, CRUD workflows.
tools: Read, Write, Edit, Bash, Grep, Glob, Task
model: opus
---
```

## Bulk Update Script

```bash
# For each agent file, add tools and model to frontmatter
# This is a conceptual script - manual review recommended

for agent in .claude/agents/**/*.md; do
  echo "Processing: $agent"
  # Review and update manually
done
```

## Verification Checklist

After updating all agents:

```bash
# Check all agents have tools:
grep -L "^tools:" .claude/agents/**/*.md
# Should return empty (no files missing tools:)

# Check all agents have model:
grep -L "^model:" .claude/agents/**/*.md
# Should return empty (no files missing model:)

# Verify frontmatter syntax
for f in .claude/agents/**/*.md; do
  head -20 "$f" | grep -E "^(name|description|tools|model):"
done
```
