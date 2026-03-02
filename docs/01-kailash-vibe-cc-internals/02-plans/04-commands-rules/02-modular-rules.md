# Modular Rules Implementation

## Why Modular Rules

Current state: All rules embedded in `CLAUDE.md`

Problems:
- Can't enable/disable individual rules
- Hard to maintain large monolithic file
- Can't share individual rule sets
- No clear categorization

Solution: Extract to `.claude/rules/` directory

## Rules to Create

### 1. security.md - Security Constraints

**File**: `.claude/rules/security.md`

```markdown
# Security Rules

## Scope
These rules apply to ALL code changes in the repository.

## MUST Rules

### 1. No Hardcoded Secrets
All sensitive data MUST use environment variables.

**Applies to**: All source files
**Enforced by**: security-reviewer agent, pre-commit hook
**Violation**: BLOCK commit

### 2. Parameterized Queries
All database queries MUST use parameterized queries or ORM.

**Applies to**: All database operations
**Enforced by**: security-reviewer agent
**Violation**: BLOCK commit

### 3. Input Validation
All user input MUST be validated before use.

**Applies to**: API endpoints, CLI inputs, file uploads
**Enforced by**: security-reviewer agent
**Violation**: HIGH priority fix

### 4. Output Encoding
All user-generated content MUST be encoded before display.

**Applies to**: Templates, HTML generation
**Enforced by**: security-reviewer agent
**Violation**: HIGH priority fix

## MUST NOT Rules

### 1. No eval() on User Input
MUST NOT use eval(), exec(), or similar on user-controlled data.

**Detection**: Static analysis
**Consequence**: BLOCK commit

### 2. No Secrets in Logs
MUST NOT log sensitive data (passwords, tokens, PII).

**Detection**: Log review
**Consequence**: CRITICAL fix required

## Exceptions
Security exceptions require:
1. Written justification
2. Approval from security-reviewer
3. Documentation in security review
```

### 2. testing.md - Testing Requirements

**File**: `.claude/rules/testing.md`

```markdown
# Testing Rules

## Scope
These rules apply to all test files and test-related code.

## MUST Rules

### 1. Test-First Development
Tests MUST be written before implementation for new features.

**Applies to**: New features, bug fixes
**Enforced by**: tdd-implementer agent
**Violation**: Code review flag

### 2. Coverage Requirements
Code changes MUST maintain or improve test coverage.

| Code Type | Minimum Coverage |
|-----------|-----------------|
| General | 80% |
| Financial | 100% |
| Authentication | 100% |
| Security-critical | 100% |

**Enforced by**: CI coverage check
**Violation**: BLOCK merge

### 3. Real Infrastructure in Tiers 2-3
Integration and E2E tests MUST use real infrastructure.

**Applies to**: Tier 2 (Integration), Tier 3 (E2E)
**Enforced by**: validate-workflow hook
**Violation**: Test invalid

## MUST NOT Rules (CRITICAL)

### 1. NO MOCKING in Tier 2-3
MUST NOT use mocking in integration or E2E tests.

**Detection**:
- @patch decorator
- MagicMock
- unittest.mock
- from mock import

**Enforced by**: validate-workflow hook
**Consequence**: Test invalid, must rewrite

## Exceptions
Testing exceptions require:
1. Written justification explaining why real infrastructure impossible
2. Approval from testing-specialist
3. Documentation in test file
```

### 3. patterns.md - Kailash Code Patterns

**File**: `.claude/rules/patterns.md`

```markdown
# Kailash Pattern Rules

## Scope
These rules apply to all Kailash SDK code.

## MUST Rules

### 1. Runtime Execution Pattern
MUST use `runtime.execute(workflow.build())`.

**Correct**:
\`\`\`python
runtime = LocalRuntime()
results, run_id = runtime.execute(workflow.build())
\`\`\`

**Incorrect**:
\`\`\`python
workflow.execute(runtime)  # WRONG
\`\`\`

**Enforced by**: validate-workflow hook
**Violation**: Code review flag

### 2. String-Based Node IDs
Node IDs MUST be string literals.

**Correct**:
\`\`\`python
workflow.add_node("NodeType", "my_node_id", {...})
\`\`\`

**Incorrect**:
\`\`\`python
workflow.add_node("NodeType", node_id_var, {...})  # WRONG
\`\`\`

**Enforced by**: Code review
**Violation**: Potential runtime issues

### 3. Absolute Imports
MUST use absolute imports for Kailash code.

**Correct**:
\`\`\`python
from kailash.workflow.builder import WorkflowBuilder
\`\`\`

**Incorrect**:
\`\`\`python
from .workflow.builder import WorkflowBuilder  # WRONG
\`\`\`

**Enforced by**: validate-workflow hook
**Violation**: Code review flag

### 4. Environment Variable Loading
MUST load .env before any operation.

**Correct**:
\`\`\`python
from dotenv import load_dotenv
load_dotenv()  # First line after imports
\`\`\`

**Enforced by**: session-start hook warning
**Violation**: Runtime errors

## Framework-Specific Rules

### DataFlow
- Primary key MUST be named `id`
- NEVER manually set `created_at`/`updated_at`
- Use FLAT params for CreateNode
- Use `filter` + `fields` for UpdateNode

### Nexus
- Register workflows before starting
- Use unified sessions for state

### Kaizen
- Use signature-based patterns
- Register agents in AgentRegistry for scale

## Exceptions
Pattern exceptions require:
1. Written justification
2. Approval from pattern-expert
3. Documentation in code comments
```

### 4. git.md - Git Workflow Rules

**File**: `.claude/rules/git.md`

```markdown
# Git Workflow Rules

## Scope
These rules apply to all git operations.

## MUST Rules

### 1. Conventional Commits
Commit messages MUST follow conventional commits format.

**Format**:
\`\`\`
type(scope): description

[optional body]

[optional footer]
\`\`\`

**Types**: feat, fix, docs, style, refactor, test, chore

**Examples**:
\`\`\`
feat(auth): add OAuth2 support
fix(api): resolve rate limiting issue
docs(readme): update installation guide
\`\`\`

**Enforced by**: Pre-commit hook (future)
**Violation**: Commit message rejection

### 2. Security Review Before Commit
MUST run security-reviewer before commit.

**Enforced by**: agents.md rule
**Violation**: Potential security issues

### 3. Branch Naming
Feature branches MUST follow naming convention.

**Format**: `type/description`

**Examples**:
- `feat/add-auth`
- `fix/api-timeout`
- `docs/update-readme`

### 4. PR Description
Pull requests MUST include:
- Summary of changes
- Test plan
- Related issues

## MUST NOT Rules

### 1. No Direct Push to Main
MUST NOT push directly to main/master branch.

**Enforced by**: Branch protection
**Consequence**: Push rejected

### 2. No Force Push to Main
MUST NOT force push to main/master.

**Consequence**: Team notification, potential rollback

### 3. No Secrets in Commits
MUST NOT commit secrets, even in history.

**Detection**: Pre-commit secret scanning
**Consequence**: History rewrite required

## Exceptions
Git exceptions require:
1. Explicit user approval
2. Documentation in PR
```

## Implementation Steps

1. Create `.claude/rules/` directory (if not exists)
2. Create each rule file
3. Update CLAUDE.md to reference rule files
4. Test rule loading in Claude session

## Verification

```bash
# Verify rules directory
ls -la .claude/rules/

# Expected:
# agents.md
# security.md
# testing.md
# patterns.md
# git.md

# In Claude session, verify rules are loaded
# Make a code change, verify appropriate rules applied
```
