# Everything Claude Code - Advanced Infrastructure

## Overview

This document covers infrastructure components not detailed in other analysis files:
- CI/CD Validation System
- Plugin Infrastructure
- Contexts System
- Testing Infrastructure
- Schema Definitions

---

## 1. CI/CD Validation System

**Location:** `scripts/ci/`

### Validation Scripts

| Script | Purpose | Validates |
|--------|---------|-----------|
| `validate-agents.js` | Agent format | YAML/markdown structure, required fields |
| `validate-commands.js` | Command format | Command file structure, naming |
| `validate-hooks.js` | Hook configuration | hooks.json against schema |
| `validate-rules.js` | Rule files | Markdown structure, required sections |
| `validate-skills.js` | Skill structure | SKILL.md presence, frontmatter |

### GitHub Workflows

**Location:** `.github/workflows/`

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | PR, push | Main validation pipeline |
| `maintenance.yml` | Scheduled | Maintenance tasks |
| `release.yml` | Tag | Release automation |
| `reusable-validate.yml` | Called | Reusable validation |
| `reusable-test.yml` | Called | Reusable testing |
| `reusable-release.yml` | Called | Reusable release |

### CI Pipeline Flow

```
PR Created/Updated
       ↓
ci.yml triggered
       ↓
┌──────────────────────────────────────────┐
│  Parallel Validation                      │
│  ├── validate-agents.js                   │
│  ├── validate-commands.js                 │
│  ├── validate-hooks.js                    │
│  ├── validate-rules.js                    │
│  └── validate-skills.js                   │
└──────────────────────────────────────────┘
       ↓
┌──────────────────────────────────────────┐
│  Integration Tests                        │
│  └── tests/run-all.js                     │
└──────────────────────────────────────────┘
       ↓
Pass/Fail Status
```

---

## 2. Plugin Infrastructure

**Location:** `.claude-plugin/`

### Plugin Manifest

**File:** `plugin.json`

```json
{
  "name": "everything-claude-code",
  "version": "1.2.0",
  "description": "Battle-tested Claude Code configurations",
  "agents": ["planner", "architect", "code-reviewer", ...],
  "skills": [...],
  "commands": [...]
}
```

### Marketplace Registration

**File:** `marketplace.json`

Contains catalog metadata for plugin marketplace listing.

### Schema Constraints

**File:** `PLUGIN_SCHEMA_NOTES.md` (5,300 bytes)

Documents undocumented validator constraints that cause silent failures:
- Field length limits
- Required vs optional fields
- Nested structure rules
- Validation edge cases

### Plugin Installation

```bash
# From marketplace
/plugin marketplace add affaan-m/everything-claude-code
/plugin install everything-claude-code@everything-claude-code

# Manual installation
git clone https://github.com/affaan-m/everything-claude-code.git
# Copy components to ~/.claude/
```

### Recommended Plugins

**Location:** `plugins/README.md`

| Category | Plugins |
|----------|---------|
| Development | typescript-lsp, pyright-lsp, hookify |
| Code Quality | code-review, pr-review-toolkit |
| Search | mgrep, context7 |
| Workflow | commit-commands, frontend-design, feature-dev |

---

## 3. Contexts System

**Location:** `contexts/`

### Pre-configured Contexts

| Context | File | Purpose |
|---------|------|---------|
| Development | `dev.md` | Active development mode |
| Review | `review.md` | PR review mode |
| Research | `research.md` | Research/exploration |

### Dynamic System Prompt Injection

```bash
# Load specific context
claude --system-prompt "$(cat contexts/dev.md)"

# Create alias for quick switching
alias claude-dev='claude --system-prompt "$(cat ~/.claude/contexts/dev.md)"'
alias claude-review='claude --system-prompt "$(cat ~/.claude/contexts/review.md)"'
alias claude-research='claude --system-prompt "$(cat ~/.claude/contexts/research.md)"'
```

### Context Pattern

Contexts modify Claude's behavior:
- **dev.md**: Focus on implementation, testing, iteration
- **review.md**: Focus on code quality, security, best practices
- **research.md**: Focus on exploration, documentation, learning

### Integration with Hooks

Contexts can be combined with session hooks:

```javascript
// scripts/hooks/session-start.js
const context = process.env.CLAUDE_CONTEXT || 'dev';
const contextPath = path.join(contextDir, `${context}.md`);
// Load context content for session
```

---

## 4. Testing Infrastructure

**Location:** `tests/`

### Test Structure

```
tests/
├── hooks/
│   └── hooks.test.js      # Hook validation tests
├── integration/
│   └── hooks.test.js      # Integration tests
├── lib/
│   ├── package-manager.test.js
│   └── utils.test.js
└── run-all.js             # Test runner
```

### Running Tests

```bash
# Run all tests
node tests/run-all.js

# Run specific test suite
node tests/hooks/hooks.test.js
node tests/lib/utils.test.js
```

### Test Coverage

| Suite | Coverage | Tests |
|-------|----------|-------|
| Hook Validation | hooks.json schema | 10+ tests |
| Package Manager | Detection logic | 8+ tests |
| Utilities | File/path operations | 15+ tests |
| Integration | Cross-component | 5+ tests |

---

## 5. Schema Definitions

**Location:** `schemas/`

### Available Schemas

| Schema | Purpose | Validation |
|--------|---------|------------|
| `package-manager.schema.json` | PM config format | Type checking, required fields |
| `hooks.schema.json` | hooks.json format | Event types, hook structure |
| `plugin.schema.json` | plugin.json format | Manifest structure |

### Schema Usage

```javascript
// In validation scripts
const Ajv = require('ajv');
const schema = require('./schemas/hooks.schema.json');
const ajv = new Ajv();
const validate = ajv.compile(schema);

if (!validate(hooksConfig)) {
  console.error(validate.errors);
}
```

---

## 6. Session Examples

**Location:** `examples/sessions/`

### Available Examples

| File | Purpose |
|------|---------|
| `2026-01-19-refactor-api.tmp` | API refactoring session |
| `2026-01-20-feature-auth.tmp` | Auth feature session |
| `2026-01-17-debugging-memory.tmp` | Memory debugging session |

### Session Pattern

`.tmp` files preserve session state across Claude restarts:
- Progress checkpoints
- What worked/didn't work
- Next steps

### Memory Persistence Pattern

```bash
# Check in progress to .tmp files
echo "Current state: implementing feature X" > session.tmp
echo "Next: write tests for Y" >> session.tmp

# Load in next session
claude --system-prompt "Previous session state: $(cat session.tmp)"
```

---

## 7. Advanced Patterns from Longform Guide

### CLI Replacement Strategy

Use CLI + skills instead of MCPs for context efficiency:

```bash
# Instead of MCP for GitHub
gh pr list  # Direct CLI
gh issue view 123  # Less context than MCP

# Instead of MCP for database
psql -c "SELECT * FROM users"  # Direct query
```

### Context Rotation

Rotate context to manage token budget:

```bash
# Clear context strategically
/compact "Keep: current task state, remove: exploration history"
```

### Session Checkpoint Pattern

```bash
# Before ending session
/checkpoint "Completed: auth API. Next: write tests. Blocked on: none"

# Resume next session
claude --resume last  # Or specific session ID
```

---

## 8. Contributing Guidelines

**File:** `CONTRIBUTING.md`

### Expected Contributions

| Category | Examples |
|----------|----------|
| Language Agents | Python, Rust, C#/.NET |
| Framework Experts | Django, Rails, Laravel |
| Domain Experts | ML pipelines, data engineering |
| DevOps | Terraform, Ansible, K8s |

### Submission Process

1. Fork repository
2. Create agent/skill/command
3. Add tests in `tests/`
4. Run validation: `node scripts/ci/validate-*.js`
5. Submit PR with description

### File Naming Conventions

- Agents: `kebab-case.md` (e.g., `python-reviewer.md`)
- Skills: Directory with `SKILL.md` (e.g., `python-patterns/SKILL.md`)
- Commands: `kebab-case.md` (e.g., `py-test.md`)

---

## Summary

This infrastructure provides:
- **Automated Validation**: CI scripts catch errors before merge
- **Plugin Ecosystem**: Easy distribution and installation
- **Context Flexibility**: Mode switching for different work types
- **Comprehensive Testing**: Quality assurance for all components
- **Schema Enforcement**: Consistent configuration formats

These components make Everything Claude Code a production-grade, maintainable system.
