# Quality Templates and Checklists

## Overview

This document provides copy-paste templates and comprehensive checklists for creating and evaluating Claude Code components. Use these as starting points and validation tools.

---

## SECTION 1: TEMPLATES

### 1.1 Agent Template

```markdown
---
name: [agent-name]
description: [Role] specialist. Use when [trigger condition]. (max 120 chars)
tools: Read, Write, Edit, Bash, Grep, Glob, Task
model: opus
---

You are a [role] specialist with expertise in [domain].

## Responsibilities
1. [Primary responsibility]
2. [Secondary responsibility]
3. [Tertiary responsibility]

## Critical Rules
1. ALWAYS [mandatory action]
2. NEVER [prohibited action]
3. [Additional constraint]

## Process
1. [First step - understand/analyze]
2. [Second step - plan/design]
3. [Third step - execute]
4. [Fourth step - verify/validate]

## Skill References
- `/[skill-name]` - [What to use it for]
- `/[another-skill]` - [What to use it for]

## Related Agents
- **[agent-name]**: Hand off when [condition]
- **[another-agent]**: Consult for [specific expertise]

## Full Documentation
When this guidance is insufficient, consult:
- `sdk-users/path/to/CLAUDE.md` - [Description]
- `sdk-users/another/path/CLAUDE.md` - [Description]
```

### 1.2 Skill Template

```markdown
---
name: [skill-name]
description: [What this provides]. Use for [specific use case].
---

# [Skill Name] Quick Reference

## Quick Patterns

### Pattern 1: [Most Common]
```python
[Copy-paste ready code - 5-10 lines]
```

### Pattern 2: [Second Most Common]
```python
[Copy-paste ready code]
```

### Pattern 3: [Third Most Common]
```python
[Copy-paste ready code]
```

## Critical Gotchas

1. **[Issue Name]**
   [One sentence explanation]
   ❌ `[Wrong code]`
   ✅ `[Correct code]`

2. **[Another Issue]**
   [One sentence explanation]
   ❌ `[Wrong code]`
   ✅ `[Correct code]`

## Common Mistakes

| Mistake | Correct Approach |
|---------|-----------------|
| [Wrong way] | [Right way] |
| [Another wrong way] | [Right way] |

## Examples

### [Use Case 1]
```python
[Complete working example with comments]
```

### [Use Case 2]
```python
[Another complete example]
```

## Related Skills
- `/[related-skill]` - [When to use]
- `/[another-skill]` - [When to use]

## Full Documentation
- `sdk-users/path/to/CLAUDE.md` - Complete reference
```

### 1.3 Hook Script Template (Node.js)

```javascript
#!/usr/bin/env node
/**
 * Hook: [HookName]
 * Event: [PreToolUse|PostToolUse|SessionStart|SessionEnd|PreCompact|Stop]
 * Purpose: [Brief description]
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Configuration
const CONFIG = {
  enabled: true,
  debug: process.env.HOOK_DEBUG === 'true',
  // Add hook-specific config
};

// Read input from stdin
let inputData = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => inputData += chunk);
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(inputData);
    const result = processHook(input);
    outputResult(result);
  } catch (error) {
    handleError(error);
  }
});

/**
 * Main hook logic
 * @param {Object} input - Hook input data
 * @returns {Object} Hook result
 */
function processHook(input) {
  const {
    session_id,
    tool_name,    // For tool hooks
    tool_input,   // For tool hooks
    cwd
  } = input;

  if (CONFIG.debug) {
    console.error(`[DEBUG] Processing ${process.env.HOOK_EVENT_NAME}`);
    console.error(`[DEBUG] Tool: ${tool_name}`);
  }

  // Implement hook logic here
  // Return: { continue: boolean, message?: string, exitCode: number }

  return {
    continue: true,
    message: null,
    exitCode: 0
  };
}

/**
 * Output result to stdout
 */
function outputResult(result) {
  const output = {
    continue: result.continue,
    hookSpecificOutput: {
      hookEventName: process.env.HOOK_EVENT_NAME,
      message: result.message
    }
  };

  console.log(JSON.stringify(output));
  process.exit(result.exitCode);
}

/**
 * Handle errors gracefully
 */
function handleError(error) {
  console.error(`[ERROR] Hook failed: ${error.message}`);

  // Non-blocking error - warn but continue
  console.log(JSON.stringify({
    continue: true,
    hookSpecificOutput: {
      error: error.message
    }
  }));

  process.exit(1); // Non-blocking error
}

// Exit codes:
// 0 = success (continue)
// 1 = non-blocking error (warn and continue)
// 2 = blocking error (stop tool execution)
```

### 1.4 Command Template

```markdown
---
name: [command-name]
description: [Brief verb-first description] (max 80 chars)
---

# /[command-name]

[One sentence explaining what this command does]

Invokes the **[agent-name]** agent for [specific task].

## Usage
```
/[command-name]                    # Basic usage
/[command-name] [required-arg]     # With required argument
/[command-name] [arg] --option     # With options
```

## Arguments
| Argument | Required | Description |
|----------|----------|-------------|
| `arg1` | Yes | What this argument does |
| `--option` | No | What this option enables |

## Examples
```
/[command-name]
/[command-name] feature-branch
/[command-name] main --force
```

## Related Commands
- `/[related]` - [Brief description]
- `/[another]` - [Brief description]
```

### 1.5 Rule File Template

```markdown
# [Category] Rules

## Scope
These rules apply to [specific context/files/operations].

## MUST Rules

### 1. [Rule Name]
[Brief explanation of why this rule exists]

**Applies to:** [Scope]
**Enforced by:** [Hook/Review/CI]
**Violation:** [What happens on violation]

### 2. [Another Rule]
[Brief explanation]

## MUST NOT Rules

### 1. [Prohibition Name]
[Why this is prohibited]

**Detection:** [How violations are detected]
**Consequence:** [Block/Warn/Fail CI]

### 2. [Another Prohibition]
[Why this is prohibited]

## Exceptions

Exceptions to these rules require:
1. Written justification in PR description
2. Approval from [role/person]
3. Documentation in [location]

Approved exceptions:
- [Exception 1]: When [condition]
- [Exception 2]: When [condition]

## Enforcement

| Rule | Pre-commit | CI | Review |
|------|------------|------|--------|
| [Rule 1] | ✓ | ✓ | ✓ |
| [Rule 2] | | ✓ | ✓ |
| [Rule 3] | | | ✓ |
```

### 1.6 Framework Documentation Template

```markdown
---
framework: [Framework Name]
version: [X.Y.Z]
last_updated: [YYYY-MM-DD]
---

# [Framework Name] Complete Reference

## Overview
[2-3 sentences explaining what this framework does and why you'd use it]

## Quick Start
```python
# Minimal working example (10 lines max)
from [framework] import [Main]

# Setup
instance = Main(config="value")

# Basic usage
result = instance.operation()
print(result)
```

## Installation

```bash
pip install kailash-[framework]
```

**Requirements:**
- Python 3.9+
- kailash >= 0.10.0
- [Other dependencies]

**Environment Variables:**
| Variable | Required | Description |
|----------|----------|-------------|
| `VAR_NAME` | Yes | What it configures |

## Core Concepts

### [Concept 1]
[Explanation]

```python
# Example demonstrating concept
```

### [Concept 2]
[Explanation]

## API Reference

### [ClassName]

Main class for [purpose].

#### Constructor
```python
ClassName(
    param1: str,           # Description
    param2: int = 10,      # Description (default: 10)
    **kwargs               # Additional options
)
```

#### Methods

##### method_name(param1, param2) → ReturnType
[Description of what method does]

**Parameters:**
- `param1` (str): Description. Required.
- `param2` (int, optional): Description. Default: 10.

**Returns:**
- `ReturnType`: Description of return value.

**Raises:**
- `ValueError`: When [condition]
- `ConnectionError`: When [condition]

**Example:**
```python
result = instance.method_name("value", 5)
```

## Patterns

### Pattern: [Name]
**Use when:** [Condition]

```python
# Complete working example
```

**Why this works:** [Explanation]

### Pattern: [Another Name]
[...]

## Configuration

### Configuration File
```yaml
# config.yaml
option1: value
option2: 10
nested:
  suboption: value
```

### Configuration Options
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `option1` | str | "default" | What it configures |
| `option2` | int | 10 | What it configures |

## Troubleshooting

### Error: [ErrorName]
```
[Error message as it appears]
```

**Cause:** [Why this error occurs]

**Solution:**
1. [Step to fix]
2. [Another step if needed]

### Error: [AnotherError]
[...]

## Migration from [Previous Version]

### Breaking Changes
1. **[Change]**: [Old way] → [New way]
2. **[Change]**: [Old way] → [New way]

### Upgrade Steps
```bash
pip install --upgrade kailash-[framework]
```

1. [First migration step]
2. [Second migration step]

## Changelog

### [Version] - [Date]
- Added: [Feature]
- Fixed: [Bug]
- Changed: [Modification]

## Related Documentation
- `sdk-users/path/to/related.md` - [Description]
- [External link] - [Description]
```

---

## SECTION 2: CHECKLISTS

### 2.1 Agent Quality Checklist

#### Frontmatter
- [ ] `name` is kebab-case
- [ ] `description` under 120 characters
- [ ] `description` includes trigger condition ("Use when...")
- [ ] `tools` explicitly lists all required tools
- [ ] `model` specified (opus/sonnet/haiku)
- [ ] Model matches task complexity

#### Content Structure
- [ ] Role defined in opening paragraph
- [ ] Responsibilities section (3-5 items)
- [ ] Critical Rules section (numbered)
- [ ] Process section (numbered steps)
- [ ] Skill References section
- [ ] Related Agents section
- [ ] Full Documentation section

#### Content Quality
- [ ] Responsibilities are high-level (not implementation)
- [ ] Rules are truly mandatory (not suggestions)
- [ ] Process is workflow, not code
- [ ] Cross-references are accurate
- [ ] No duplicate content from skills

#### Anti-Patterns
- [ ] No implementation code in body
- [ ] No documentation duplication
- [ ] No vague responsibilities
- [ ] Under 300 lines total

### 2.2 Skill Quality Checklist

#### Frontmatter
- [ ] `name` matches directory name
- [ ] `description` states use case clearly
- [ ] SKILL.md is entry point

#### Content Structure
- [ ] Quick Patterns section (3-5 patterns)
- [ ] Critical Gotchas section
- [ ] Common Mistakes section (table format)
- [ ] Examples section (tested code)
- [ ] Related Skills section
- [ ] Full Documentation section

#### Content Quality
- [ ] Patterns are copy-paste ready
- [ ] Examples are tested and working
- [ ] Gotchas highlight real issues
- [ ] References to sdk-users are accurate
- [ ] No policy/process content (belongs in agents)

#### Anti-Patterns
- [ ] No tutorial-style explanations
- [ ] No duplicated patterns from other skills
- [ ] No untested code examples
- [ ] Under 250 lines total

### 2.3 Hook Quality Checklist

#### Configuration
- [ ] Matcher is specific (not overly broad)
- [ ] Timeout is appropriate (<10s for PreToolUse)
- [ ] Script path is valid
- [ ] Cross-platform compatible

#### Script Quality
- [ ] Handles JSON input correctly
- [ ] Uses appropriate exit codes
- [ ] Fails gracefully (non-blocking default)
- [ ] Includes error messages
- [ ] No external dependencies beyond stdlib

#### Logic Quality
- [ ] Logic is deterministic
- [ ] No LLM-like reasoning
- [ ] Completes within timeout
- [ ] Side effects are safe

### 2.4 Command Quality Checklist

- [ ] Name is verb-first
- [ ] Name is 1-2 words
- [ ] Description under 80 characters
- [ ] Delegates to agent/skill
- [ ] Arguments documented
- [ ] Examples provided
- [ ] Related commands listed
- [ ] Under 50 lines

### 2.5 Rule Quality Checklist

- [ ] Scope clearly defined
- [ ] MUST rules are mandatory
- [ ] MUST NOT rules prevent harm
- [ ] Exceptions documented
- [ ] Enforcement mechanism specified
- [ ] Rules are testable
- [ ] No contradictions
- [ ] Under 100 lines

### 2.6 Documentation Quality Checklist

#### Structure
- [ ] CLAUDE.md entry point exists
- [ ] Frontmatter includes version
- [ ] All standard sections present
- [ ] Logical organization

#### Content
- [ ] All code examples tested
- [ ] All parameters documented
- [ ] All return types specified
- [ ] Common errors covered
- [ ] Cross-references accurate

#### Maintenance
- [ ] Version numbers current
- [ ] No broken links
- [ ] No "TODO" markers
- [ ] Examples match current API

---

## SECTION 3: QUALITY SCORES

### Component Quality Rating

Use this rubric to rate component quality:

| Score | Level | Description |
|-------|-------|-------------|
| 9-10 | Excellent | Exemplary, could be used as template |
| 7-8 | Good | Minor improvements needed |
| 5-6 | Adequate | Functional but needs work |
| 3-4 | Poor | Significant issues |
| 1-2 | Failing | Major rewrite needed |

### Current Kailash Setup Scores

| Component | Score | Issues |
|-----------|-------|--------|
| Agents | 8.5/10 | Missing tool declarations, cross-refs |
| Skills | 7.8/10 | Duplication, DataFlow bloat |
| Hooks | 0/10 | Not implemented |
| Commands | N/A | Using skills as commands |
| Rules | 7/10 | Embedded in CLAUDE.md |
| Documentation | 8.5/10 | Missing root navigation |

### Target Scores
- All components: 8.5+/10
- Critical components (agents, skills): 9+/10

---

## SECTION 4: REVIEW PROCEDURES

### New Component Review

1. **Structural Review**
   - Run through relevant checklist
   - Count lines (within limits?)
   - Check frontmatter completeness

2. **Content Review**
   - Read for clarity
   - Verify cross-references
   - Test code examples

3. **Integration Review**
   - Check for duplicates with existing components
   - Verify naming conventions
   - Ensure proper categorization

### Periodic Audit

**Monthly:**
- Count lines per component (detect bloat)
- Test random code examples
- Check for broken references

**Quarterly:**
- Full component inventory
- Duplicate detection across skills
- User feedback integration

### Improvement Workflow

```
1. Identify issue (checklist failure, user feedback)
        ↓
2. Document in issue tracker
        ↓
3. Assign severity (Critical/High/Medium/Low)
        ↓
4. Create fix PR
        ↓
5. Review against checklist
        ↓
6. Merge and update scores
```
