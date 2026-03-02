# Kailash Setup - Agents Deep Analysis

## Agent Architecture

The Kailash setup organizes 18 agents into functional groups with clear responsibilities. Unlike Everything Claude Code's general-purpose agents, these are **framework-specific specialists**.

## Complete Agent Inventory (18 Agents)

### Analysis & Planning Agents

#### 1. deep-analyst
**File**: `.claude/agents/deep-analyst.md`

**Purpose**: Deep failure analysis, complexity assessment, root cause investigation

**Key Behaviors**:
- Systematic failure point identification
- Complexity assessment
- Root cause analysis
- Dependency mapping

**Usage Trigger**: Starting complex features, debugging systemic issues

#### 2. requirements-analyst
**File**: `.claude/agents/requirements-analyst.md`

**Purpose**: Requirements breakdown, systematic analysis, ADR creation

**Key Behaviors**:
- User story extraction
- Acceptance criteria definition
- ADR (Architecture Decision Record) creation
- Scope definition

**Usage Trigger**: New feature requirements, unclear specifications

#### 3. sdk-navigator
**File**: `.claude/agents/sdk-navigator.md`

**Purpose**: Documentation navigation, pattern discovery, existing solutions

**Key Behaviors**:
- Find patterns before coding
- Resolve errors during development
- Navigate sdk-users documentation
- Discover existing solutions

**Usage Trigger**: Before implementing anything, when encountering errors

#### 4. framework-advisor
**File**: `.claude/agents/framework-advisor.md`

**Purpose**: Framework selection guidance

**Key Decision**:
```
User Request → Framework Advisor →
├── Core SDK (fine-grained control)
├── DataFlow (database operations)
├── Nexus (multi-channel deployment)
└── Kaizen (AI agents)
```

**Usage Trigger**: Starting new features, architectural decisions

### Framework Specialists (frameworks/ subdirectory)

#### 5. dataflow-specialist
**File**: `.claude/agents/frameworks/dataflow-specialist.md`

**Purpose**: Database operations with auto-generated nodes (v0.10.15+)

**Key Expertise**:
- @db.model decorator → 9 auto-generated nodes per model
- CRUD operations: CREATE, READ, UPDATE, DELETE, LIST, UPSERT, COUNT
- Bulk operations: BULK_CREATE, BULK_UPDATE, BULK_DELETE, BULK_UPSERT
- Multi-database: PostgreSQL, MySQL, SQLite
- Migrations with 8 specialized engines
- Multi-tenancy, soft deletes, audit trails

**Critical Knowledge**:
- NEVER manually set `created_at`/`updated_at`
- CreateNode uses FLAT params; UpdateNode uses `filter` + `fields`
- Primary key MUST be named `id`
- `soft_delete` only affects DELETE, NOT queries

**Usage Trigger**: Any database operation

#### 6. nexus-specialist
**File**: `.claude/agents/frameworks/nexus-specialist.md`

**Purpose**: Multi-channel platform implementation

**Key Expertise**:
- Zero-config deployment (API + CLI + MCP)
- Unified session management
- DataFlow integration
- Event system and plugins
- Health monitoring

**Usage Trigger**: Platform deployment, API creation

#### 7. kaizen-specialist
**File**: `.claude/agents/frameworks/kaizen-specialist.md`

**Purpose**: AI agent framework implementation (v1.0.0)

**Key Expertise**:
- Unified Agent API (2-line quickstart to expert mode)
- Signature-based programming
- Multi-agent coordination (A2A protocol)
- Multi-modal processing (vision, audio, text)
- BaseAgent architecture
- Autonomous execution modes
- Agent memory systems

**Usage Trigger**: AI agent development, agentic workflows

#### 8. mcp-specialist
**File**: `.claude/agents/frameworks/mcp-specialist.md`

**Purpose**: Model Context Protocol implementation

**Key Expertise**:
- MCP server implementation
- MCP client integration
- Tools, resources, prompts
- Authentication patterns
- Transport types (stdio, HTTP, SSE)

**Usage Trigger**: MCP integration, AI tool development

### Implementation & Review Agents

#### 9. pattern-expert
**File**: `.claude/agents/pattern-expert.md`

**Purpose**: Workflow patterns, node selection, parameter passing

**Key Expertise**:
- WorkflowBuilder patterns
- Node selection from 110+ nodes
- Parameter passing conventions
- Connection patterns
- Cyclic workflow patterns

**Usage Trigger**: Workflow implementation, debugging patterns

#### 10. tdd-implementer
**File**: `.claude/agents/tdd-implementer.md`

**Purpose**: Test-first development with tier-based strategy

**Key Expertise**:
- 3-tier testing (Unit, Integration, E2E)
- NO MOCKING policy for Tiers 2-3
- Real infrastructure testing
- Write-test-then-code workflow

**Testing Tiers**:
```
Tier 1 (Unit):        Mock allowed, fast, isolated
Tier 2 (Integration): NO MOCKING, real services
Tier 3 (E2E):         NO MOCKING, full system
```

**Usage Trigger**: Feature implementation

#### 11. intermediate-reviewer
**File**: `.claude/agents/intermediate-reviewer.md`

**Purpose**: Checkpoint reviews after milestones

**Key Behaviors**:
- Progress validation
- Milestone verification
- Todo completion checking
- Quality gate enforcement

**Usage Trigger**: After todo-manager creates tasks, after tdd-implementer completes

#### 12. gold-standards-validator
**File**: `.claude/agents/gold-standards-validator.md`

**Purpose**: Compliance checking against mandatory patterns

**Key Checks**:
- Absolute imports validation
- Parameter validation patterns
- Error handling standards
- NO MOCKING policy enforcement
- Workflow structure validation
- Security validation

**Usage Trigger**: Before commits, during code review

### Testing & Documentation Agents

#### 13. testing-specialist
**File**: `.claude/agents/testing-specialist.md`

**Purpose**: 3-tier testing strategy implementation

**Key Expertise**:
- Tier selection guidance
- Real infrastructure testing
- Test organization patterns
- Coverage requirements

**Usage Trigger**: Test implementation, debugging test failures

#### 14. documentation-validator
**File**: `.claude/agents/documentation-validator.md`

**Purpose**: Code example testing, documentation accuracy

**Key Behaviors**:
- Execute code examples
- Verify documentation accuracy
- Update outdated examples
- Cross-reference with sdk-users

**Usage Trigger**: Documentation updates, example creation

### Frontend Specialists (frontend/ subdirectory)

#### 15. frontend-developer
**File**: `.claude/agents/frontend/frontend-developer.md`

**Purpose**: Responsive UI components, page implementation

**Key Expertise**:
- Modular architecture patterns
- @tanstack/react-query integration
- Shadcn UI components
- API integration patterns

**Usage Trigger**: Page creation, UI component implementation

#### 16. react-specialist
**File**: `.claude/agents/frontend/react-specialist.md`

**Purpose**: React 19, Next.js 15, React Flow

**Key Expertise**:
- React 19 patterns
- Next.js 15 App Router
- React Flow workflow editors
- Shadcn UI integration
- Kailash SDK frontend integration

**Usage Trigger**: React/Next.js implementation

#### 17. flutter-specialist
**File**: `.claude/agents/frontend/flutter-specialist.md`

**Purpose**: Flutter 3.27+, Material Design 3

**Key Expertise**:
- Flutter 3.27+ patterns
- Material Design 3
- Riverpod state management
- Kailash SDK mobile integration
- Cross-platform development

**Usage Trigger**: Flutter/mobile implementation

#### 18. uiux-designer
**File**: `.claude/agents/frontend/uiux-designer.md`

**Purpose**: Design system, interaction patterns, accessibility

**Key Expertise**:
- Information architecture
- Visual hierarchy
- Enterprise SaaS patterns
- Accessibility (WCAG)
- Design token systems

**Usage Trigger**: Design system work, UX decisions

### Release & Operations Agents

#### 19. deployment-specialist
**File**: `.claude/agents/deployment-specialist.md`

**Purpose**: Docker, Kubernetes, environment management

**Key Expertise**:
- Docker containerization
- Kubernetes orchestration
- Environment management
- Service scaling
- Infrastructure-as-code

**Usage Trigger**: Deployment setup, infrastructure changes

#### 20. git-release-specialist
**File**: `.claude/agents/git-release-specialist.md`

**Purpose**: Git workflows, CI/CD, versioning

**Key Expertise**:
- Pre-commit validation
- PR workflows
- Release procedures
- CI/CD pipelines
- Semantic versioning

**Usage Trigger**: Commits, PRs, releases

#### 21. todo-manager
**File**: `.claude/agents/todo-manager.md`

**Purpose**: Task management, project tracking

**Key Behaviors**:
- Todo hierarchy maintenance
- Task breakdown
- Progress tracking
- Integration with Claude Code todo system

**Usage Trigger**: Task creation, project planning

#### 22. gh-manager
**File**: `.claude/agents/gh-manager.md`

**Purpose**: GitHub project sync, issue management

**Key Behaviors**:
- User story creation
- Sprint management
- GitHub Projects sync
- Issue tracking

**Usage Trigger**: Project management, sprint planning

## Agent Orchestration Patterns

### Standard Development Flow
```
framework-advisor → (framework-specialist) →
tdd-implementer → pattern-expert →
gold-standards-validator → intermediate-reviewer
```

### Analysis Flow
```
deep-analyst → requirements-analyst →
sdk-navigator → framework-advisor
```

### Deployment Flow
```
testing-specialist → documentation-validator →
deployment-specialist → git-release-specialist
```

## Comparison with Everything Claude Code

| Aspect | Everything CC | Kailash Setup |
|--------|---------------|---------------|
| Total Agents | 12 | 18 |
| Framework-Specific | No | Yes (4 specialists) |
| Frontend Coverage | Limited | Comprehensive (4 agents) |
| DevOps | Limited | Full (deployment + git) |
| AI Development | No | Yes (kaizen-specialist) |
| Project Management | No | Yes (todo + gh manager) |
| Documentation Testing | No | Yes |

## Unique Strengths

1. **Framework Specialists**: Deep knowledge of DataFlow, Nexus, Kaizen, MCP
2. **Frontend Coverage**: React, Flutter, UX design
3. **Full DevOps**: Deployment + release management
4. **AI-Native**: Built for AI agent development
5. **Documentation Integration**: sdk-users as single source of truth
