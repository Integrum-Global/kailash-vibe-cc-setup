# Immediate Action Items

## CRITICAL: Implementation Sequence

**Do NOT implement Priority 1 items in parallel.** Follow this exact sequence:

```
Step 1: Create infrastructure directories
   ↓
Step 2: Create scripts/hooks/ directory and scripts
   ↓
Step 3: Create .claude/rules/ directory and agents.md
   ↓
Step 4: Create .claude/settings.json with hooks configuration
   ↓
Step 5: Create .claude/agents/security-reviewer.md
   ↓
Step 6: Create mcp-configs/ directory and configuration files
```

### Settings File Strategy

**IMPORTANT**: Understand the difference:
- `.claude/settings.json` - Main configuration (hooks, settings) - **CREATE THIS**
- `.claude/settings.local.json` - Local overrides (permissions) - **EXISTS, DON'T MODIFY**

Hooks go in `settings.json`, NOT `settings.local.json`.

---

## Priority 1: Critical Gaps (This Week)

### 1.1 Implement Hooks Infrastructure

**Why Critical**: Hooks provide deterministic automation that doesn't rely on LLM decisions. Without hooks:
- No automatic formatting
- No input validation
- No session persistence
- No learning observation

**Implementation**:

1. Create hooks configuration:
```bash
# Create hooks directory structure
mkdir -p scripts/hooks
```

2. Add to `.claude/settings.json`:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "command": "scripts/hooks/validate-bash-command.js",
          "timeout": 10
        }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{
          "type": "command",
          "command": "scripts/hooks/auto-format.js",
          "timeout": 30
        }]
      }
    ],
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "scripts/hooks/session-start.js"
      }]
    }],
    "SessionEnd": [{
      "hooks": [{
        "type": "command",
        "command": "scripts/hooks/session-end.js"
      }]
    }],
    "PreCompact": [{
      "hooks": [{
        "type": "command",
        "command": "scripts/hooks/pre-compact.js"
      }]
    }]
  }
}
```

3. Create hook scripts (see Everything CC's scripts/hooks/ for reference).

**Validation**: Run a session and verify hooks fire.

---

### 1.2 Add Security-Reviewer Agent

**Why Critical**: Security checks are currently implicit. Without explicit security review:
- Vulnerabilities may ship
- OWASP Top 10 not systematically checked
- Secrets may leak

**Implementation**:

Create `.claude/agents/security-reviewer.md`:
```markdown
---
name: security-reviewer
description: Security vulnerability specialist. Use proactively before commits and for security-sensitive code changes.
tools: Read, Grep, Glob
model: opus
---

You are a senior security engineer reviewing code for vulnerabilities.

## Mandatory Checks
1. **Secrets Detection**
   - No hardcoded API keys, passwords, tokens
   - Environment variables for sensitive data
   - .env files not committed

2. **Input Validation**
   - All user input validated
   - Type checking on boundaries
   - Length limits enforced

3. **SQL Injection Prevention**
   - Parameterized queries only
   - No string concatenation in SQL
   - ORM usage verified

4. **XSS Prevention**
   - Output encoding in templates
   - Content-Security-Policy headers
   - innerHTML avoided

5. **Authentication/Authorization**
   - Auth checks on protected routes
   - Session management secure
   - Token validation proper

6. **Rate Limiting**
   - API endpoints rate limited
   - Login attempts throttled
   - Resource exhaustion prevented

## Review Format
Provide findings as:
- **CRITICAL**: Must fix before commit
- **HIGH**: Should fix before merge
- **MEDIUM**: Fix in next iteration
- **LOW**: Consider fixing
```

**Validation**: Test by reviewing a file with known issues.

---

### 1.3 Add MCP Configurations with Context Warnings

**Why Critical**: Users don't know MCP context impact. Without warnings:
- Context exhaustion surprises
- Too many MCPs enabled
- Poor context utilization

**Implementation**:

1. Create `mcp-configs/` directory:
```bash
mkdir -p mcp-configs
```

2. Create `mcp-configs/README.md`:
```markdown
# MCP Configuration Guide

## CRITICAL: Context Impact Warning

**200k total context → ~70k with too many MCPs**

Each MCP server consumes context for:
- Server description
- Tool definitions
- Resource schemas

## Safe Limits
- 20-30 MCPs configured maximum
- <10 enabled per project
- <80 tools active at any time

## Recommended Configurations

### Minimal (kailash-minimal.json)
- github: PR and issue management
- memory: Session persistence
Context cost: ~10k

### Development (kailash-dev.json)
- github
- memory
- filesystem (if needed)
Context cost: ~15k

### Full Stack (kailash-full.json)
- github
- memory
- database (project-specific)
- deployment (Vercel/Railway)
Context cost: ~25k

## Check Your Context
Run `/context` to see current utilization.
```

3. Create `mcp-configs/kailash-minimal.json`:
```json
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    },
    "memory": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"]
    }
  }
}
```

---

### 1.4 Add Mandatory Review Rules

**Why Critical**: Code review is optional. Without mandatory rules:
- Quality inconsistent
- Security issues missed
- Technical debt accumulates

**Implementation**:

Create `.claude/rules/agents.md`:
```markdown
# Agent Orchestration Rules

## MANDATORY Delegations

These delegations are NOT optional:

### 1. After ANY Code Change
Immediately invoke code review:
- All file edits
- All new files
- All deletions

### 2. Before ANY Commit
Invoke security-reviewer:
- Check for secrets
- Validate input handling
- Review authentication

### 3. For Complex Features
Start with analysis chain:
deep-analyst → requirements-analyst → framework-advisor

### 4. For Framework-Specific Work
Consult appropriate specialist:
- Database operations → dataflow-specialist
- API/platform → nexus-specialist
- AI agents → kaizen-specialist
- MCP integration → mcp-specialist

## Parallel Execution

ALWAYS use parallel execution for independent operations:
- Multiple file reads
- Independent searches
- Non-dependent analyses

## Multi-Perspective Analysis

For architectural decisions, use multiple viewpoints:
- framework-advisor (selection)
- pattern-expert (implementation)
- testing-specialist (testability)
```

---

## Priority 2: Important Additions (Next Week)

### 2.1 Add Build-Fix Agent

Create `.claude/agents/build-fix.md`:
```markdown
---
name: build-fix
description: Fix build and type errors with minimal changes. Use when builds fail. NO architectural changes allowed.
tools: Read, Write, Edit, Bash, Grep, Glob
model: opus
---

You fix build errors with the SMALLEST possible change.

## CRITICAL RULES
1. **NO architectural changes** - Fix the error only
2. **NO refactoring** - Even if code is ugly
3. **NO feature additions** - Even if related
4. **NO style changes** - Unless causing the error
5. **Minimal diff** - Smallest change that fixes

## Process
1. Read exact error message
2. Locate error source
3. Determine minimal fix
4. Apply change
5. Verify error resolved
6. Ensure no new errors

## Anti-Patterns to Avoid
- "While I'm here, let me also..."
- "This would be cleaner if..."
- "A better approach would be..."
- "This is a good opportunity to..."

## Success Criteria
- Error fixed: YES
- Lines changed: MINIMAL
- New errors: NONE
- Functionality preserved: YES
```

### 2.2 Add Context Management to CLAUDE.md

Add this section to the root CLAUDE.md:
```markdown
## Context Management

### MCP Context Impact
Each MCP server reduces available context:
- 200k total context budget
- Each MCP: ~2-5k context cost
- Too many MCPs: ~70k available (65% loss)

### Safe Limits
- Configure: 20-30 MCPs maximum
- Enable: <10 per project
- Active tools: <80

### Check Context
- `/context` - View current utilization
- `/compact` - Compress when >80% used

### Recommended Sets
See `mcp-configs/README.md` for project-appropriate configurations.
```

### 2.3 Add E2E Runner Agent

Create `.claude/agents/e2e-runner.md`:
```markdown
---
name: e2e-runner
description: End-to-end testing specialist. Use for generating and running Playwright tests.
tools: Read, Write, Edit, Bash, Grep, Glob
model: opus
---

You generate and run comprehensive E2E tests using Playwright.

## Patterns
1. **Page Object Model** - Encapsulate page interactions
2. **User Journeys** - Test complete flows
3. **Artifacts** - Screenshots, videos, traces

## Test Structure
```typescript
test.describe('Feature Name', () => {
  test('user can complete journey', async ({ page }) => {
    // Arrange
    await page.goto('/');

    // Act
    await page.click('[data-testid="action"]');

    // Assert
    await expect(page.locator('[data-testid="result"]')).toBeVisible();
  });
});
```

## Artifact Collection
Always configure:
- Screenshots on failure
- Video on retry
- Trace on failure
```

---

## Priority 3: Enhancements (Following Weeks)

### 3.1 Add Continuous Learning Skill

Adapt Everything CC's continuous-learning-v2 for Kailash ecosystem.

### 3.2 Add Iterative Retrieval Skill

Implement subagent context refinement pattern.

### 3.3 Add Memorable Skill Aliases

Update skill descriptions to include common aliases.

### 3.4 Package as Plugin

Create `.claude-plugin/plugin.json` for easy distribution.

---

## Hook Testing Procedures

### Testing PreToolUse Hooks
```bash
# 1. Start Claude Code session with verbose logging
claude --verbose

# 2. Trigger a Bash command
# In session: "Run ls -la"

# 3. Check for hook output in terminal
# Should see: "PreToolUse hook triggered for Bash"
```

### Testing PostToolUse Hooks (Auto-Format)
```bash
# 1. Create a test Python file with bad formatting
echo "def foo():  return    1" > /tmp/test.py

# 2. In Claude session, edit the file
# "Edit /tmp/test.py to add a docstring"

# 3. Verify formatting was applied
cat /tmp/test.py  # Should be formatted by black/prettier
```

### Testing SessionStart/End
```bash
# 1. Start a session
claude

# 2. Do some work, then exit
# Type: exit

# 3. Check for session state file
ls ~/.claude/sessions/  # Should contain state file

# 4. Resume session
claude --resume last
# Previous context should be available
```

### Testing Security-Reviewer
```bash
# In Claude session:
# "Review /path/to/file.py for security issues"
# Should get OWASP-based security analysis
```

---

## Rollback Strategy

### Before Making Changes
```bash
# ALWAYS backup first
cp -r .claude .claude.backup.$(date +%Y%m%d)
```

### If Hooks Break Sessions
```bash
# Remove hooks configuration temporarily
mv .claude/settings.json .claude/settings.json.broken

# Sessions will work without hooks
# Debug the broken hooks file
```

### If Security-Reviewer Causes Issues
```bash
# Disable specific agent
mv .claude/agents/security-reviewer.md .claude/agents/security-reviewer.md.disabled
```

### If MCP Configs Cause Problems
```bash
# Remove MCP directory
mv mcp-configs mcp-configs.broken

# Or disable specific MCP in ~/.claude.json
```

### Full Rollback
```bash
# Restore from backup
rm -rf .claude
mv .claude.backup.YYYYMMDD .claude
```

---

## Validation Checklist

After implementing Priority 1 items, verify:

- [ ] **Hooks**: PostToolUse fires after file edits
- [ ] **Hooks**: SessionStart/End persist state
- [ ] **Security**: security-reviewer agent responds to delegation
- [ ] **MCPs**: Configuration files load correctly
- [ ] **MCPs**: Context warnings visible in README
- [ ] **Rules**: agents.md loaded and enforced
- [ ] **CLAUDE.md**: Context management section present
