# Everything Claude Code - Skills Deep Analysis

## Skill Architecture

Skills in Everything Claude Code are broader workflow definitions that:
- Provide domain knowledge
- Define coding standards
- Implement complex multi-step workflows
- Support continuous learning

## Complete Skills Inventory (24 Skills)

### Category 1: Core Development Standards

#### coding-standards/
**File**: `skills/coding-standards/SKILL.md`

**Coverage**:
- TypeScript/JavaScript patterns
- React/Node.js conventions
- Immutability (CRITICAL - always use spread operator)
- Error handling patterns
- Type safety requirements
- API design standards
- File organization (200-400 lines typical, 800 max)
- Comments and documentation

**Key Pattern - Immutability**:
```typescript
// CORRECT - Always use spread
const updated = { ...obj, newProp: value };

// WRONG - Never mutate directly
obj.newProp = value;
```

#### backend-patterns/
**File**: `skills/backend-patterns/SKILL.md`

**Coverage**:
- Repository pattern
- Service pattern
- Middleware pattern
- Database query optimization
- N+1 prevention
- Transaction management
- Caching strategies
- Authentication/Authorization
- Rate limiting
- Background jobs
- Structured logging

#### frontend-patterns/
**File**: `skills/frontend-patterns/SKILL.md`

**Coverage**:
- Component structure
- Custom hooks
- State management
- Conditional rendering
- Performance optimization

### Category 2: Quality Assurance

#### tdd-workflow/
**File**: `skills/tdd-workflow/SKILL.md`

**RED-GREEN-REFACTOR Cycle**:
```
1. RED:       Write failing test FIRST
2. GREEN:     Write minimal implementation to pass
3. REFACTOR:  Improve while keeping tests green
4. VERIFY:    Check coverage (80%+ required)
```

**Test Types (ALL Mandatory)**:
- Unit tests (individual functions)
- Integration tests (API endpoints, database)
- E2E tests (critical user flows - Playwright)

**Coverage Requirements**:
- 80% minimum for all code
- 100% required for: financial code, auth, security-critical, core business logic

#### security-review/
**File**: `skills/security-review/SKILL.md`

**Coverage**:
- OWASP Top 10 checklist
- Common vulnerability patterns
- Input validation
- Output encoding
- Secret management

**Directory Structure**:
```
security-review/
├── SKILL.md
├── agents/
├── hooks/
└── scripts/
```

### Category 3: Continuous Learning (Advanced)

#### continuous-learning/ (v1)
Basic pattern extraction from sessions.

#### continuous-learning-v2/ (ADVANCED)
**Most sophisticated skill in the repository**

**Architecture**:
```
Session Activity →
Hooks (PreToolUse/PostToolUse - 100% reliable) →
observations.jsonl →
Observer Agent (Haiku model) →
Pattern Detection →
Instincts (0.3-0.9 confidence) →
Clustering (via /evolve) →
Skills/Commands/Agents
```

**File Structure**:
```
~/.claude/homunculus/
├── identity.json
├── observations.jsonl (current session)
├── observations.archive/ (processed)
├── instincts/
│   ├── personal/ (auto-learned)
│   └── inherited/ (imported)
└── evolved/ (generated outputs)
```

**Confidence Evolution**:
| Score | Level | Behavior |
|-------|-------|----------|
| 0.3 | Tentative | Suggested, not enforced |
| 0.5 | Moderate | Applied when relevant |
| 0.7 | Strong | Auto-approved |
| 0.9 | Near-certain | Core behavior |

**Why v2 is Superior**:
- v1: Skills-based observation (50-80% reliable)
- v2: Hooks-based observation (100% reliable - every tool call captured)

**Associated Commands**:
- `/instinct-status` - View learned instincts
- `/evolve` - Cluster instincts into skills
- `/instinct-export` - Export instincts for sharing
- `/instinct-import` - Import instincts from others

### Category 4: Context Management

#### iterative-retrieval/
**File**: `skills/iterative-retrieval/SKILL.md`

**Purpose**: Solve the "context problem" in multi-agent workflows

**4-Phase DISPATCH→EVALUATE→REFINE→LOOP Cycle**:
```
1. DISPATCH - Broad initial query
2. EVALUATE - Score relevance (0.2-1.0)
3. REFINE   - Update search based on evaluation
4. LOOP     - Repeat (max 3 cycles)
```

**Result**: Progressive refinement achieving 3+ high-relevance files

**Problem Solved**: Subagents don't know what context they need until they start working

#### strategic-compact/
**File**: `skills/strategic-compact/SKILL.md`

**Purpose**: Manual compaction suggestions for token optimization

### Category 5: Verification

#### eval-harness/
**File**: `skills/eval-harness/SKILL.md`

**Coverage**:
- Checkpoint vs continuous evals
- Grader types
- pass@k metrics

#### verification-loop/
**File**: `skills/verification-loop/SKILL.md`

**Purpose**: Continuous verification patterns

### Category 6: Language-Specific (Go)

#### golang-patterns/
**File**: `skills/golang-patterns/SKILL.md`

**Coverage**: Go idioms and best practices

#### golang-testing/
**File**: `skills/golang-testing/SKILL.md`

**Coverage**: Go testing patterns, TDD, benchmarks

### Category 7: Database

#### postgres-patterns/
**File**: `skills/postgres-patterns/SKILL.md`

**Coverage**: PostgreSQL-specific best practices

#### clickhouse-io/
**File**: `skills/clickhouse-io/SKILL.md`

**Coverage**: ClickHouse analytics patterns

### Category 8: Java/Spring (Enterprise)

#### java-coding-standards/
Java best practices and conventions

#### jpa-patterns/
JPA (Java Persistence API) patterns

#### springboot-patterns/
Spring Boot application patterns

#### springboot-security/
Spring Boot security configurations

#### springboot-tdd/
Spring Boot test-driven development

#### springboot-verification/
Spring Boot verification patterns

### Category 9: Project Configuration

#### project-guidelines-example/
**File**: `skills/project-guidelines-example/SKILL.md`

**Purpose**: Template for project-specific guidelines

## Skill Organization Principles

### Directory Structure
```
skill-name/
├── SKILL.md (required - entry point)
├── README.md (optional - additional docs)
├── agents/ (optional - associated agents)
├── hooks/ (optional - lifecycle hooks)
└── scripts/ (optional - helper scripts)
```

### Invocation Methods
1. **Automatic**: Claude detects when skill is relevant from description
2. **Manual**: User types `/skill-name`
3. **By Agent**: Agent preloads skills via `skills` frontmatter field

### Storage Locations
- User-level: `~/.claude/skills/`
- Project-level: `.claude/skills/`
- Plugin-provided: Via plugin installation

## Gap Analysis

### Strengths
1. Comprehensive TDD workflow
2. Sophisticated continuous learning system
3. Clear coding standards
4. Language-specific support (Go, Java)
5. Database patterns

### Missing
1. No Python-specific patterns
2. No Rust patterns
3. No mobile development (React Native, Flutter)
4. No AI/ML workflow patterns
5. No DevOps/infrastructure patterns
6. Limited frontend framework coverage (React only)
