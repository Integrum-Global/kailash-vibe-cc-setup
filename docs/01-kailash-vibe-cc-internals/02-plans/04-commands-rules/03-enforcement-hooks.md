# Enforcement Hooks Specification

## Overview

This document specifies how rules from `.claude/rules/` are enforced via hooks. Hooks provide deterministic enforcement (100% reliable) vs LLM-based enforcement (70-80% reliable).

## Hook Exit Codes

| Code | Meaning | Effect |
|------|---------|--------|
| `0` | Continue | Operation proceeds normally |
| `1` | Warn | Warning logged, operation continues |
| `2` | Block | Operation blocked, user notified |

## Enforcement Architecture

```
RULE (in .claude/rules/)
     │
     ▼
HOOK (in scripts/hooks/)
     │
     ├── PreToolUse → Block before tool execution
     ├── PostToolUse → Validate after tool execution
     └── Stop → Final cleanup and validation
```

## Rule-to-Hook Mapping

### Security Rules → Multiple Hooks

| Rule | Hook | Type | Detection |
|------|------|------|-----------|
| No hardcoded secrets | `validate-bash-command.js` | PreToolUse | Regex for API keys, tokens |
| No secrets in logs | `validate-workflow.js` | PostToolUse | Log output scanning |
| Input validation | Code review delegation | Agent | security-reviewer |

**Implementation** (`scripts/hooks/security-validation.js`):

```javascript
#!/usr/bin/env node

const secretPatterns = [
  /['"]?api[_-]?key['"]?\s*[:=]\s*['"][^'"]{20,}['"]/i,
  /['"]?token['"]?\s*[:=]\s*['"][^'"]{20,}['"]/i,
  /['"]?password['"]?\s*[:=]\s*['"][^'"]{8,}['"]/i,
  /['"]?secret['"]?\s*[:=]\s*['"][^'"]{20,}['"]/i,
  /AKIA[0-9A-Z]{16}/,  // AWS access key
  /ghp_[a-zA-Z0-9]{36}/,  // GitHub token
];

function detectSecrets(content) {
  for (const pattern of secretPatterns) {
    if (pattern.test(content)) {
      return { blocked: true, reason: "Potential secret detected in code" };
    }
  }
  return { blocked: false };
}

// Hook integration
const input = JSON.parse(require('fs').readFileSync(0, 'utf8'));
const result = detectSecrets(input.content || '');
if (result.blocked) {
  console.error(JSON.stringify({ error: result.reason }));
  process.exit(2);  // BLOCK
}
process.exit(0);  // CONTINUE
```

### Testing Rules → validate-workflow.js

| Rule | Detection Method | Exit Code |
|------|-----------------|-----------|
| NO MOCKING in Tier 2-3 | Pattern scan | `2` (block) |
| Real infrastructure | Import analysis | `1` (warn) |
| Test coverage | Coverage report | `1` (warn) |

**Mock Detection** (`scripts/hooks/validate-workflow.js` addition):

```javascript
const mockPatterns = [
  { regex: /@patch\(/, description: "@patch decorator" },
  { regex: /MagicMock/, description: "MagicMock usage" },
  { regex: /from\s+mock\s+import/, description: "mock import" },
  { regex: /from\s+unittest\.mock/, description: "unittest.mock import" },
  { regex: /mock\.patch/, description: "mock.patch usage" },
];

function detectMocking(content, filePath) {
  // Only check test files
  if (!filePath.match(/test[s]?\//)) return { blocked: false };

  // Only check Tier 2-3 tests (integration, e2e)
  const isTier23 = filePath.match(/integration|e2e|tests\/(integration|e2e)/);
  if (!isTier23) return { blocked: false };

  for (const pattern of mockPatterns) {
    if (pattern.regex.test(content)) {
      return {
        blocked: true,
        reason: `NO MOCKING POLICY VIOLATION: ${pattern.description} in Tier 2-3 test`,
        severity: "CRITICAL"
      };
    }
  }
  return { blocked: false };
}
```

### Pattern Rules → validate-workflow.js

| Rule | Pattern | Anti-Pattern |
|------|---------|--------------|
| Runtime execution | `runtime.execute(workflow.build())` | `workflow.execute(runtime)` |
| Absolute imports | `from kailash.xxx` | `from .xxx` |
| String node IDs | `"node_id"` | `variable` |
| .env loading | `load_dotenv()` | Missing dotenv |

**Pattern Validation**:

```javascript
const kailashPatterns = {
  runtimeExecution: {
    correct: /runtime\s*\.\s*execute\s*\(\s*workflow\s*\.\s*build\s*\(\s*\)/,
    antiPattern: /workflow\s*\.\s*execute\s*\(\s*runtime/,
    message: "Use runtime.execute(workflow.build()), NOT workflow.execute(runtime)"
  },
  absoluteImports: {
    correct: /from\s+kailash\./,
    antiPattern: /from\s+\.\s*(workflow|nodes|runtime)/,
    message: "Use absolute imports: from kailash.xxx, NOT from .xxx"
  },
  templateSyntax: {
    correct: /\$\{[^}]+\}/,
    antiPattern: /\{\{[^}]+\}\}/,
    message: "Use ${} template syntax, NOT {{}}"
  }
};

function validatePatterns(content, filePath) {
  // Skip non-Python files
  if (!filePath.endsWith('.py')) return { issues: [] };

  const issues = [];

  for (const [name, pattern] of Object.entries(kailashPatterns)) {
    if (pattern.antiPattern.test(content)) {
      issues.push({
        rule: name,
        message: pattern.message,
        severity: "HIGH"
      });
    }
  }

  return { issues };
}
```

### Git Rules → Pre-Commit Integration

| Rule | Enforcement Point | Implementation |
|------|------------------|----------------|
| Conventional commits | PreToolUse | Validate commit message |
| No direct push to main | PreToolUse | Block push command |
| PR description | Agent delegation | git-release-specialist |

**Git Command Validation**:

```javascript
function validateGitCommand(command) {
  // Block direct push to main
  if (/git\s+push.*\s+(origin\s+)?(main|master)(?!\:)/.test(command)) {
    return {
      blocked: true,
      reason: "Direct push to main/master blocked. Use feature branches and PRs."
    };
  }

  // Block force push to main
  if (/git\s+push\s+(-f|--force)/.test(command) &&
      /main|master/.test(command)) {
    return {
      blocked: true,
      reason: "Force push to main/master is FORBIDDEN."
    };
  }

  // Warn on destructive commands
  if (/git\s+reset\s+--hard/.test(command)) {
    return {
      blocked: false,
      warning: "git reset --hard is destructive. Consider git stash instead."
    };
  }

  return { blocked: false };
}
```

## Hook Configuration

Add to `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": { "tool_name": "Bash" },
        "hooks": [
          {
            "type": "command",
            "command": "scripts/hooks/validate-bash-command.js",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": { "tool_name": "Write" },
        "hooks": [
          {
            "type": "command",
            "command": "scripts/hooks/validate-workflow.js",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": { "tool_name": "Edit" },
        "hooks": [
          {
            "type": "command",
            "command": "scripts/hooks/validate-workflow.js",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": { "tool_name": "Write" },
        "hooks": [
          {
            "type": "command",
            "command": "scripts/hooks/auto-format.js",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

## Enforcement Levels

### Level 1: BLOCK (Exit Code 2)

Rules that MUST be enforced - violation blocks operation:

| Rule | Reason |
|------|--------|
| NO MOCKING in Tier 2-3 | Test integrity |
| No hardcoded secrets | Security critical |
| No force push to main | Team safety |
| Workflow anti-patterns | Runtime errors |

### Level 2: WARN (Exit Code 1)

Rules that SHOULD be followed - warning logged:

| Rule | Reason |
|------|--------|
| Relative imports | Will work but inconsistent |
| Missing .env load | May fail at runtime |
| Coverage decrease | Quality degradation |

### Level 3: INFORM (Exit Code 0)

Rules for information - no action:

| Rule | Reason |
|------|--------|
| Documentation suggestion | Nice to have |
| Style preference | Team decision |

## Validation Flow

```
User Request
     │
     ▼
PreToolUse Hook ──────────────────┐
     │                            │
     ├── Level 1 Violation? ──Yes──► Block (exit 2)
     │                            │
     ├── Level 2 Violation? ──Yes──► Warn (exit 1)
     │                            │
     ▼                            │
Tool Execution ◄──────────────────┘
     │
     ▼
PostToolUse Hook
     │
     ├── Format violations? ──Yes──► Auto-fix
     │
     ├── Pattern violations? ──Yes──► Log for review
     │
     ▼
Continue
```

## Testing Enforcement

### Test NO MOCKING Detection

```python
# tests/enforcement/test_mock_detection.py
"""Test that mock detection correctly identifies violations."""

def test_detects_patch_decorator():
    content = '''
@patch("module.function")
def test_something(mock_func):
    pass
'''
    result = detect_mocking(content, "tests/integration/test_db.py")
    assert result["blocked"] == True
    assert "NO MOCKING" in result["reason"]

def test_allows_tier1_mocks():
    content = '''
@patch("module.function")
def test_something(mock_func):
    pass
'''
    result = detect_mocking(content, "tests/unit/test_helper.py")
    assert result["blocked"] == False
```

### Test Pattern Detection

```python
# tests/enforcement/test_pattern_detection.py
"""Test that pattern detection identifies anti-patterns."""

def test_detects_workflow_execute_antipattern():
    content = "workflow.execute(runtime)"
    result = validate_patterns(content, "src/app.py")
    assert len(result["issues"]) > 0
    assert "runtime.execute" in result["issues"][0]["message"]

def test_allows_correct_pattern():
    content = "results, run_id = runtime.execute(workflow.build())"
    result = validate_patterns(content, "src/app.py")
    assert len(result["issues"]) == 0
```

## Extending Enforcement

### Adding a New Rule

1. **Define in rule file** (`.claude/rules/xxx.md`):
   ```markdown
   ### New Rule Name
   MUST [requirement].

   **Enforced by**: [hook name]
   **Violation**: [BLOCK/WARN]
   ```

2. **Add detection to hook**:
   ```javascript
   const newRulePatterns = {
     correct: /pattern/,
     antiPattern: /anti-pattern/,
     message: "Explanation"
   };
   ```

3. **Test the detection**:
   ```python
   def test_new_rule_detection():
       # Test anti-pattern detected
       # Test correct pattern allowed
   ```

4. **Document in this spec**:
   - Add to rule-to-hook mapping
   - Add to enforcement level

## Fallback Behavior

When hooks fail or timeout:

```javascript
// Always allow on hook failure (fail-open)
try {
  const result = validateContent(input);
  if (result.blocked) {
    process.exit(2);
  }
} catch (error) {
  console.error(JSON.stringify({
    warning: "Validation hook failed, proceeding anyway",
    error: error.message
  }));
  process.exit(0);  // CONTINUE on error
}
```

This ensures hooks never block the developer's work due to hook bugs, while still providing enforcement when functioning correctly.

## Implementation Priority

1. **Week 1**: NO MOCKING detection (highest impact)
2. **Week 1**: Pattern validation (prevents runtime errors)
3. **Week 2**: Secret detection (security critical)
4. **Week 2**: Git command validation (team safety)
5. **Week 3**: Full test coverage
