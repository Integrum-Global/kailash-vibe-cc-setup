# Everything Claude Code - Agents Deep Analysis

## Agent Architecture

Each agent in Everything Claude Code follows a consistent pattern:
- **Limited Tool Scope**: Security through restriction
- **Model Selection**: Opus for complex tasks
- **Focused Purpose**: One responsibility per agent
- **Mandatory Usage**: Certain agents must be used (e.g., code-reviewer after every change)

## Complete Agent Inventory (12 Agents)

### 1. Planner Agent
**File**: `agents/planner.md`
**Tools**: Read, Grep, Glob
**Model**: Opus

**Purpose**: Implementation planning with user confirmation

**Key Behaviors**:
- Restates requirements to ensure understanding
- Identifies risks and dependencies
- Creates step-by-step implementation plans
- **CRITICAL**: WAITS for user confirmation before implementation

**Usage Trigger**: Complex feature requests

### 2. Architect Agent
**File**: `agents/architect.md`
**Tools**: Read, Grep, Glob
**Model**: Opus

**Purpose**: System design and technical decisions

**Key Behaviors**:
- High-level architecture design
- Trade-off analysis
- ADR (Architecture Decision Record) creation
- Scalability planning
- Pattern recommendations

**Usage Trigger**: Architectural decisions, system design questions

### 3. Code-Reviewer Agent
**File**: `agents/code-reviewer.md`
**Tools**: Read, Write, Edit, Bash, Grep, Glob
**Model**: Opus

**Purpose**: Quality and security review

**Key Behaviors**:
- Code quality assessment
- Security vulnerability detection
- Maintainability review
- **MANDATORY**: Must be used after ALL code changes

**Usage Trigger**: Immediately after any code modification

### 4. TDD-Guide Agent
**File**: `agents/tdd-guide.md`
**Tools**: Read, Write, Edit, Bash, Grep
**Model**: Opus

**Purpose**: Enforce test-driven development

**Key Behaviors**:
- RED-GREEN-REFACTOR cycle enforcement
- 80%+ coverage requirement
- Test structure guidance
- Write tests FIRST

**Usage Trigger**: Bug fixes or new features

### 5. Security-Reviewer Agent
**File**: `agents/security-reviewer.md`
**Tools**: Read, Write, Edit, Bash, Grep, Glob
**Model**: Opus

**Purpose**: Security vulnerability specialist

**Key Behaviors**:
- OWASP Top 10 analysis
- Secrets detection
- Input validation review
- **CRITICAL**: Mandatory pre-commit security check

**Usage Trigger**: Before any commit

### 6. Build-Error-Resolver Agent
**File**: `agents/build-error-resolver.md`
**Tools**: Read, Write, Edit, Bash, Grep, Glob
**Model**: Opus

**Purpose**: Fix TypeScript/build errors with minimal changes

**Key Behaviors**:
- **NO architectural changes** - only error fixes
- Minimal diffs policy
- TypeScript expertise
- Build system knowledge

**Usage Trigger**: Build failures, type errors

### 7. E2E-Runner Agent
**File**: `agents/e2e-runner.md`
**Tools**: (implied: Bash, Read, Write)
**Model**: Opus

**Purpose**: End-to-end testing

**Key Behaviors**:
- Generate Playwright E2E tests
- Page Object Model pattern
- Artifact generation (screenshots, videos, traces)

**Usage Trigger**: E2E test requirements

### 8. Refactor-Cleaner Agent
**File**: `agents/refactor-cleaner.md`
**Tools**: Read, Write, Edit, Grep, Glob
**Model**: Opus

**Purpose**: Dead code removal

**Key Behaviors**:
- Identify unused code
- Safe deletion
- Import cleanup

**Usage Trigger**: Code maintenance, cleanup tasks

### 9. Doc-Updater Agent
**File**: `agents/doc-updater.md`
**Tools**: Read, Write, Edit, Grep, Glob
**Model**: Opus

**Purpose**: Documentation synchronization

**Key Behaviors**:
- Keep docs in sync with code
- API documentation updates
- README maintenance

**Usage Trigger**: After significant code changes

### 10. Database-Reviewer Agent
**File**: `agents/database-reviewer.md`
**Tools**: Read, Grep, Glob
**Model**: Opus

**Purpose**: Database operation review

**Key Behaviors**:
- Query optimization review
- N+1 detection
- Transaction safety
- Index recommendations

**Usage Trigger**: Database-related changes

### 11. Go-Reviewer Agent (Language-Specific)
**File**: `agents/go-reviewer.md`
**Tools**: Read, Grep, Glob
**Model**: Opus

**Purpose**: Go-specific code review

**Key Behaviors**:
- Go idioms enforcement
- Error handling patterns
- Concurrency safety

**Usage Trigger**: Go project code review

### 12. Go-Build-Resolver Agent (Language-Specific)
**File**: `agents/go-build-resolver.md`
**Tools**: Read, Write, Edit, Bash, Grep, Glob
**Model**: Opus

**Purpose**: Go build error resolution

**Key Behaviors**:
- Go compilation errors
- Module management
- Dependency resolution

**Usage Trigger**: Go build failures

## Agent Orchestration Patterns

### Immediate Delegation Rules
The `rules/agents.md` file defines when to delegate:

1. **Complex feature requests** → Planner Agent
2. **Code just written/modified** → Code-Reviewer Agent
3. **Bug fix or new feature** → TDD-Guide Agent
4. **Architectural decisions** → Architect Agent
5. **Security-sensitive code** → Security-Reviewer Agent

### Parallel Execution
- ALWAYS use parallel execution for independent operations
- Multi-perspective analysis via split-role subagents

### Sequential Chains
```
User Request → Planner → TDD-Guide → [Implementation] → Code-Reviewer → Security-Reviewer → Commit
```

## Tool Restriction Philosophy

Each agent has carefully restricted tools:

| Agent | Read | Write | Edit | Bash | Grep | Glob |
|-------|------|-------|------|------|------|------|
| Planner | ✓ | ✗ | ✗ | ✗ | ✓ | ✓ |
| Architect | ✓ | ✗ | ✗ | ✗ | ✓ | ✓ |
| Code-Reviewer | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| TDD-Guide | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ |
| Build-Error-Resolver | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

**Rationale**:
- Planners shouldn't modify code (read-only exploration)
- Implementers need full access
- Reviewers need to suggest fixes

## Gap Analysis

### Strengths
1. Clear responsibility separation
2. Mandatory usage patterns
3. Quality gate enforcement
4. Language-specific agents (Go)

### Missing
1. No frontend-specific agents (React, Flutter)
2. No deployment/DevOps agent
3. No AI/ML agent for agent development
4. No multi-framework support (single-language focus)
