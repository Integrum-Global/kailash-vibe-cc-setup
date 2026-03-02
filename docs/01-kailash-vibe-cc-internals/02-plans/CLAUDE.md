# Implementation Plans - CodeGen Entry Point

## Purpose

This document serves as the entry point for implementing improvements to the Kailash Vibe CC Setup. Use this when executing the plans in this directory.

## Critical Context

### Quality Philosophy

The goal is not just to add features, but to create a **self-improving autonomous guidance system**. Each component must:

1. **Be Actionable**: Every instruction should be immediately implementable
2. **Be Specific**: No vague guidance - exact file paths, code, configurations
3. **Be Testable**: Clear validation criteria for each component
4. **Be Maintainable**: Single source of truth, no duplication

### Component Roles (Validated Hierarchy)

```
USER REQUEST
     │
     ▼
AGENTS (Policy Layer - 100-300 lines)
├── Know WHAT to do and WHEN
├── Delegate to skills for HOW
├── Fall back to sdk-users for edge cases
├── NEVER contain implementation details
└── ALWAYS have tools/model in frontmatter
     │
     ├──► SKILLS (Pattern Layer - 50-250 lines)
     │    ├── 80% actionable patterns
     │    ├── 20% references to full docs
     │    └── NO policy, NO tutorials
     │
     ├──► HOOKS (Automation Layer - deterministic)
     │    ├── 100% reliable (vs LLM 70-80%)
     │    ├── <10s for PreToolUse
     │    └── NO complex reasoning
     │
     └──► RULES (Constraint Layer)
          ├── MUST = mandatory, enforced
          ├── MUST NOT = prohibited, blocked
          └── Testable and specific
```

## Implementation Sequence

### Phase 1: Automation Foundation (Days 1-3)

**Goal**: Enable deterministic automation without LLM dependency.

```bash
# Step 1: Backup
cp -r .claude .claude.backup.$(date +%Y%m%d)

# Step 2: Create directories
mkdir -p scripts/hooks
mkdir -p .claude/rules
mkdir -p .claude/commands
mkdir -p mcp-configs

# Step 3: Implement in this order
# See: 01-hooks-infrastructure/
```

**Files to Create (Priority 1)**:
1. `scripts/hooks/validate-bash-command.js` - Block dangerous commands
2. `scripts/hooks/validate-workflow.js` - Enforce runtime.execute(workflow.build())
3. `scripts/hooks/auto-format.js` - Python (black) + JS/TS (prettier)
4. `scripts/hooks/session-start.js` - Load previous state
5. `scripts/hooks/session-end.js` - Persist current state
6. `scripts/hooks/pre-compact.js` - Save critical context
7. `.claude/settings.json` - Hook configuration

### Phase 2: Agent Enhancement (Days 3-5)

**Goal**: Complete agent infrastructure with mandatory reviews.

**Files to Create**:
1. `.claude/agents/security-reviewer.md` - OWASP-based security checks
2. `.claude/agents/build-fix.md` - Minimal diff error resolution
3. `.claude/rules/agents.md` - Mandatory delegation rules

**Files to Modify** (All 22 agents):
```yaml
# ADD to every agent frontmatter:
---
name: existing-name
description: existing description
tools: Read, Write, Edit, Bash, Grep, Glob, Task  # ADD THIS
model: opus  # ADD THIS (or sonnet/haiku based on complexity)
---

# ADD sections at end of each agent:
## Related Agents
- **agent-name**: Hand off when [condition]

## Full Documentation
When this guidance is insufficient, consult:
- `sdk-users/path/to/CLAUDE.md`
```

### Phase 3: Skills & Commands (Days 6-8)

**Goal**: Optimize skill content and add memorable commands.

**Deduplication Required**:
- 4-param pattern appears in 5 places → Keep only in `01-core-sdk`
- DataFlow SKILL.md: 570 lines → Target 250 lines

**Commands to Create**:
| Command | Points To | Purpose |
|---------|-----------|---------|
| `/sdk` | `01-core-sdk` | Core SDK patterns |
| `/db` | `02-dataflow` | DataFlow patterns |
| `/api` | `03-nexus` | Nexus deployment |
| `/ai` | `04-kaizen` | Kaizen agents |
| `/test` | `12-testing-strategies` | Testing patterns |
| `/validate` | `17-gold-standards` | Compliance check |

### Phase 4: MCP & Learning (Days 9-14)

**Goal**: Add context management and learning infrastructure.

**MCP Configuration Files**:
- `kailash-minimal.json` - GitHub + memory (~15k context)
- `kailash-dev.json` - + filesystem (~25k context)
- `kailash-full.json` - + database + deployment (~35k context)

**Learning System Design**:
```
~/.claude/kailash-learning/
├── observations.jsonl    # Hook-captured observations
├── instincts/
│   └── personal/         # Auto-learned patterns
└── evolved/              # Generated skills/commands
```

## Quality Validation Checklist

### Agent Quality
```
For EACH agent, verify:
[_] Frontmatter has: name, description, tools, model
[_] Description under 120 chars with "Use when [trigger]"
[_] Responsibilities are high-level (3-5 items)
[_] Critical Rules are truly mandatory
[_] Has Related Agents section
[_] Has Full Documentation section
[_] Total lines: 100-300
```

### Skill Quality
```
For EACH skill, verify:
[_] Has SKILL.md entry point
[_] Quick Patterns: 3-5 copy-paste ready
[_] Critical Gotchas: formatted with ❌/✅
[_] No duplicate content from other skills
[_] References sdk-users for details
[_] Total lines: 50-250
```

### Hook Quality
```
For EACH hook, verify:
[_] Uses correct exit codes (0=continue, 2=block)
[_] Handles JSON input/output
[_] Fails gracefully (non-blocking default)
[_] Completes within timeout (PreToolUse: <10s)
[_] No external dependencies beyond Node.js stdlib
```

### Rule Quality
```
For EACH rule, verify:
[_] Scope clearly defined
[_] MUST rules are enforceable
[_] MUST NOT rules are detectable
[_] Has enforcement mechanism specified
[_] No contradictions with other rules
```

## Kailash-Specific Hooks

Beyond standard hooks, implement these Kailash-specific validations:

### 1. Workflow Build Validation
```javascript
// Detect anti-pattern: workflow.execute(runtime)
// Enforce pattern: runtime.execute(workflow.build())
const antiPattern = /workflow\s*\.\s*execute\s*\(\s*runtime/;
const correctPattern = /runtime\s*\.\s*execute\s*\(\s*workflow\s*\.\s*build\s*\(\s*\)/;
```

### 2. Absolute Import Validation
```javascript
// Block relative imports in Kailash code
const relativeImport = /from\s+['"]\./;  // from "." or from '.'
```

### 3. NO MOCKING Enforcement (Tier 2-3)
```javascript
// Detect mocking in test files
const mockPatterns = [
  /@patch\(/,
  /MagicMock/,
  /mock\./,
  /unittest\.mock/
];
```

### 4. DataFlow Primary Key Validation
```javascript
// Ensure primary key is named 'id'
const wrongPK = /primary_key\s*=\s*True.*(?!id:)/;
```

## Testing Each Component

### Test Hooks
```bash
# 1. Start verbose session
claude --verbose

# 2. Trigger PreToolUse (Bash validation)
# In session: "Run ls -la"
# Expected: Hook fires, command proceeds

# 3. Trigger PostToolUse (auto-format)
# Edit a .py file
# Expected: black formats the file

# 4. Test session persistence
# Exit and resume: claude --resume last
# Expected: Previous state loaded
```

### Test Agents
```bash
# In Claude session:
# "Review this file for security issues: /path/to/file.py"
# Expected: security-reviewer responds with OWASP-based analysis

# "Fix this build error: [error message]"
# Expected: build-fix responds with minimal diff solution
```

### Test Rules
```bash
# In Claude session after code change:
# Expected: Automatic delegation to code-reviewer
# Before commit: Automatic delegation to security-reviewer
```

## Rollback Procedures

### Hook Issues
```bash
# Disable all hooks
mv .claude/settings.json .claude/settings.json.disabled
# Sessions work without hooks

# Disable specific hook
# Edit .claude/settings.json to remove the hook entry
```

### Agent Issues
```bash
# Disable specific agent
mv .claude/agents/security-reviewer.md \
   .claude/agents/security-reviewer.md.disabled
```

### Full Rollback
```bash
rm -rf .claude
mv .claude.backup.YYYYMMDD .claude
rm -rf scripts/hooks
rm -rf mcp-configs
```

## Plan Navigation

| Plan | When to Use |
|------|-------------|
| `01-hooks-infrastructure/` | Implementing automation |
| `02-agents-enhancement/` | Adding/improving agents |
| `03-skills-optimization/` | Fixing skill duplication |
| `04-commands-rules/` | Adding commands, rules |
| `05-mcp-configuration/` | Setting up MCPs |
| `06-continuous-learning/` | Learning system |
| `07-autonomous-integration/` | Full system wiring |

## Success Criteria

The implementation is successful when:

1. **Automation**: All 6 hook types fire correctly
2. **Security**: Security review required before every commit
3. **Quality**: Code review automatic after every change
4. **Context**: MCP warnings visible, limits enforced
5. **Learning**: Observations captured for future improvement
6. **Validation**: CI scripts catch configuration errors
