# Rules Philosophy and Quality Guide

## First Principles

### What Rules ARE
- **Behavioral Constraints**: Define what MUST or MUST NOT happen
- **Quality Guards**: Ensure consistent standards
- **Policy Enforcers**: Make policies mandatory, not optional
- **Cross-Cutting Concerns**: Apply across all operations

### What Rules are NOT
- **Implementation Guides**: Should constrain, not instruct
- **Documentation**: Should be brief, not explanatory
- **Suggestions**: Should be mandatory, not optional

## The Rule Contract

```
INPUT: Claude Code operation in progress
       ↓
RULE RESPONSIBILITIES:
1. Constrain behavior (what MUST happen)
2. Prevent violations (what MUST NOT happen)
3. Ensure quality (what standards apply)
4. Guide escalation (when to seek review)
       ↓
OUTPUT: Compliant operation or blocked with reason
```

## Structure Standards

### Rule File Structure
```markdown
# Rule Category Name

## Scope
[Where this rule applies]

## MUST Rules
1. [Non-negotiable requirement]
2. [Another requirement]

## MUST NOT Rules
1. [Prohibited action]
2. [Another prohibition]

## Exceptions
[When rules can be relaxed and who can approve]

## Enforcement
[How violations are detected/handled]
```

### Rule Categories

#### 1. Security Rules
```markdown
# Security Rules

## MUST Rules
1. MUST NOT commit secrets (API keys, passwords, tokens)
2. MUST validate all user input
3. MUST use parameterized queries (no SQL concatenation)
4. MUST sanitize output in templates

## MUST NOT Rules
1. MUST NOT use eval() or exec() on user input
2. MUST NOT disable security headers
3. MUST NOT bypass authentication checks
```

#### 2. Code Style Rules
```markdown
# Code Style Rules

## MUST Rules
1. MUST use absolute imports (Kailash projects)
2. MUST follow 4-param node pattern
3. MUST include type hints (Python 3.9+)

## MUST NOT Rules
1. MUST NOT use relative imports
2. MUST NOT use mocking in Tier 2-3 tests
3. MUST NOT skip .build() on workflows
```

#### 3. Testing Rules
```markdown
# Testing Rules

## MUST Rules
1. MUST write tests before implementation (TDD)
2. MUST use real infrastructure in Tier 2-3
3. MUST achieve 80%+ coverage for new code

## MUST NOT Rules
1. MUST NOT mock in integration/E2E tests
2. MUST NOT skip tests for "quick" changes
3. MUST NOT commit with failing tests
```

#### 4. Git Rules
```markdown
# Git Rules

## MUST Rules
1. MUST use conventional commit format
2. MUST review before pushing
3. MUST create PR for main branch

## MUST NOT Rules
1. MUST NOT push to main directly
2. MUST NOT use --force without approval
3. MUST NOT commit large binaries
```

#### 5. Agent Orchestration Rules
```markdown
# Agent Orchestration Rules

## MUST Rules
1. MUST invoke code-reviewer after ANY change
2. MUST invoke security-reviewer before commits
3. MUST invoke framework specialist for framework work

## MUST NOT Rules
1. MUST NOT skip mandatory reviews
2. MUST NOT implement without consulting specialist
3. MUST NOT ignore reviewer findings
```

## Quality Criteria

### Length Guidelines
| Quality | Lines | Purpose |
|---------|-------|---------|
| Minimal (20-40) | Single concern | Security-only rules |
| Standard (40-80) | Domain rules | Testing rules |
| Comprehensive (80-120) | Cross-cutting | Agent orchestration |
| Too Long (>150) | Split needed | Too many concerns |

### Rule Strength Levels
```
MUST (mandatory):
├── Violation blocks operation
├── No exceptions without approval
└── Enforced by hooks when possible

SHOULD (strong preference):
├── Violation triggers warning
├── Exceptions with justification
└── Enforced by review

MAY (suggestion):
├── Violation noted but allowed
├── Contextual application
└── Not enforced
```

## Quality Checklist

### Structural Quality
- [ ] Clear scope defined
- [ ] MUST rules are truly mandatory
- [ ] MUST NOT rules prevent real harms
- [ ] Exceptions documented with approval process
- [ ] Enforcement mechanism specified

### Content Quality
- [ ] Rules are testable (can verify compliance)
- [ ] Rules are actionable (clear what to do)
- [ ] Rules don't contradict each other
- [ ] Rules align with project goals

### Anti-Patterns Avoided
- [ ] No vague rules ("write good code")
- [ ] No impossible rules ("never make mistakes")
- [ ] No redundant rules (covered elsewhere)
- [ ] No unenforced rules (toothless)

## Kailash-Specific Rules

### Existing Rules (in CLAUDE.md)
```markdown
1. Always use Kailash SDK frameworks (never build from scratch)
2. Always use specialist subagents
3. Always load .env before ANY operation
4. Always use runtime.execute(workflow.build())
5. NO MOCKING in Tiers 2-3
6. String-based node IDs
```

### Missing Rules (RECOMMENDED)

#### Rule: Mandatory Code Review
```markdown
## Agent Orchestration: Code Review

### MUST Rules
1. MUST invoke intermediate-reviewer after ANY file change
2. MUST invoke security-reviewer before ANY commit
3. MUST invoke gold-standards-validator for new patterns

### Enforcement
- Hooks detect file changes
- Hooks require review before commit
- PR checks require passing validation
```

#### Rule: Framework Consultation
```markdown
## Agent Orchestration: Framework Specialists

### MUST Rules
1. MUST consult dataflow-specialist before any database operation
2. MUST consult nexus-specialist before any API/platform work
3. MUST consult kaizen-specialist before any AI agent work
4. MUST consult mcp-specialist before any MCP integration

### MUST NOT Rules
1. MUST NOT use SQLAlchemy/Django ORM directly
2. MUST NOT use FastAPI directly
3. MUST NOT implement custom agent patterns
4. MUST NOT implement custom MCP patterns

### Exceptions
Approved by framework specialist with documented justification.
```

#### Rule: Testing Standards
```markdown
## Testing: Tier Requirements

### Tier 1 (Unit Tests)
- MAY use mocking for isolation
- MUST test pure functions
- SHOULD achieve 90%+ coverage

### Tier 2 (Integration Tests)
- MUST NOT use mocking
- MUST use real database
- MUST test actual integrations

### Tier 3 (E2E Tests)
- MUST NOT use mocking
- MUST use production-like environment
- MUST test user journeys

### Enforcement
- Pre-commit hook checks for mock usage
- CI fails on mock detection in Tier 2-3
```

## Rule Placement Strategy

### In CLAUDE.md (Root)
- Critical, always-applicable rules
- Framework directives
- Runtime patterns

### In .claude/rules/ (Modular)
- Domain-specific rules
- Easily updatable
- Can be enabled/disabled

### In Hooks (Automated)
- Enforceable rules
- Pre/post operation checks
- Deterministic validation

## Current Gap

Kailash has rules embedded in CLAUDE.md but no modular rule files.

**Recommendation**: Extract to `.claude/rules/`:
1. `security.md` - Security constraints
2. `testing.md` - Testing requirements
3. `agents.md` - Agent orchestration
4. `patterns.md` - Code patterns
5. `git.md` - Git workflow

## Template: Kailash Rule File

```markdown
# [Category] Rules

## Scope
These rules apply to [specific context].

## MUST Rules

### [Rule Name]
[Brief explanation]
- Applies to: [scope]
- Enforced by: [mechanism]

### [Another Rule]
[Brief explanation]

## MUST NOT Rules

### [Prohibition Name]
[Why this is prohibited]
- Detection: [how to detect violations]
- Consequence: [what happens on violation]

## Exceptions
Exceptions require:
1. Written justification
2. Approval from [role]
3. Documentation in [location]

## Enforcement
- Pre-commit: [hooks that enforce]
- CI: [automated checks]
- Review: [manual review points]
```
