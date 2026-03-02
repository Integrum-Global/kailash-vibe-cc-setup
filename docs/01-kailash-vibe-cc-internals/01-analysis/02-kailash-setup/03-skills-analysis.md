# Kailash Setup - Skills Deep Analysis

## Skill Architecture

The Kailash setup organizes skills into 17 numbered categories with SKILL.md entry points. Unlike Everything Claude Code's standalone skills, these are **deeply integrated with sdk-users documentation**.

## Complete Skills Inventory (17 Categories, 100+ Skills)

### 01-core-sdk
**Purpose**: WorkflowBuilder, runtime patterns, node patterns

**Key Skills**:
- Workflow creation patterns
- Node configuration
- Parameter passing (flat vs nested)
- Connection patterns
- Runtime execution (sync vs async)
- Cyclic workflow patterns
- Error handling
- MCP integration basics

**Core Pattern**:
```python
from kailash.workflow.builder import WorkflowBuilder
from kailash.runtime import LocalRuntime

workflow = WorkflowBuilder()
workflow.add_node("NodeName", "id", {"param": "value"})
runtime = LocalRuntime()
results, run_id = runtime.execute(workflow.build())  # ALWAYS .build()
```

### 02-dataflow
**Purpose**: Database operations with auto-generated nodes

**Key Skills** (25+ skills):
- Model definition with @db.model decorator
- Auto-generated nodes (9 per model):
  - CRUD: CREATE, READ, UPDATE, DELETE, LIST, UPSERT, COUNT
  - Bulk: BULK_CREATE, BULK_UPDATE, BULK_DELETE, BULK_UPSERT
- Query patterns
- Migration system (8 engines)
- Multi-database support
- Transaction management
- Multi-tenancy patterns
- Soft delete configuration
- Audit trail setup

**Critical Gotchas**:
1. NEVER manually set `created_at`/`updated_at`
2. CreateNode uses FLAT params; UpdateNode uses `filter` + `fields`
3. Primary key MUST be named `id`
4. `soft_delete` only affects DELETE, NOT queries
5. Use `$null`/`$exists` operators for NULL checking

### 03-nexus
**Purpose**: Multi-channel deployment (API/CLI/MCP)

**Key Skills** (8+ skills):
- Zero-config platform deployment
- API endpoint registration
- CLI command generation
- MCP tool exposure
- Unified session management
- DataFlow integration
- Event system
- Plugin architecture
- Health monitoring

### 04-kaizen
**Purpose**: AI agents with signature-based programming

**Key Skills** (10+ skills):
- Unified Agent API (v1.0.0)
- BaseAgent architecture
- Signature-based programming
- Multi-agent coordination
- A2A (Agent-to-Agent) protocol
- Multi-modal processing (vision, audio, text)
- Agent memory systems
- Autonomous execution modes
- Prompt optimization
- Chain-of-thought patterns

**Quick Start**:
```python
from kaizen.api import Agent

# 2-line quickstart
agent = Agent(model="gpt-4")
result = await agent.run("What is IRP?")

# Autonomous mode
agent = Agent(
    model="gpt-4",
    execution_mode="autonomous",
    memory="session",
    tool_access="constrained",
)
```

### 05-mcp
**Purpose**: Model Context Protocol server implementation

**Key Skills** (8+ skills):
- MCP server creation
- Tool definitions
- Resource definitions
- Prompt definitions
- Authentication patterns
- Transport types (stdio, HTTP, SSE)
- MCP testing strategies
- Progress reporting
- Structured tools

### 06-cheatsheets
**Purpose**: Quick reference patterns

**Key Skills** (12+ skills):
- Common mistakes
- Node selection guide
- Workflow patterns library
- Cycle patterns
- Production patterns
- Performance optimization
- Monitoring setup
- Security configuration
- Multi-tenancy quickstart
- Distributed transactions
- Saga pattern
- Custom node basics
- PythonCode data science
- Ollama integration
- DirectoryReader patterns
- Environment variable handling

### 07-development-guides
**Purpose**: Advanced development patterns

**Key Skills** (15+ skills):
- Custom node development
- Async node development
- MCP development
- Testing strategies
- Production deployment
- RAG implementation
- Security patterns
- Monitoring setup
- Circuit breaker patterns
- Compliance patterns
- Edge computing
- SDK internals

### 08-nodes-reference
**Purpose**: Complete 110+ node catalog

**Categories**:
- **AI Nodes**: LLM integration, embeddings, vision
- **API Nodes**: HTTP, REST, GraphQL
- **Code Nodes**: PythonCode, evaluation
- **Data Nodes**: Transform, filter, aggregate
- **Database Nodes**: Auto-generated per model
- **File Nodes**: Read, write, parse
- **Logic Nodes**: Switch, condition, loop
- **Monitoring Nodes**: Metrics, logging, alerts
- **Admin Nodes**: Configuration, health
- **Transaction Nodes**: Saga, compensation
- **Transform Nodes**: JSON, XML, CSV

### 09-workflow-patterns
**Purpose**: Industry-specific patterns

**Industries**:
- Finance workflows
- Healthcare workflows
- Logistics workflows
- Manufacturing workflows
- Retail workflows

**Use Cases**:
- ETL workflows
- RAG workflows
- API integration workflows
- Document processing
- Business rules engines
- Project management

### 10-deployment-git
**Purpose**: Deployment and version control

**Key Skills** (10+ skills):
- Docker deployment
- Kubernetes orchestration
- Docker Compose patterns
- CI/CD pipelines
- Git branching strategies
- Pre-commit validation
- Release procedures
- Environment management

### 11-frontend-integration
**Purpose**: React and Flutter integration

**Key Skills** (8+ skills):
- React setup with Kailash
- @tanstack/react-query integration
- Flutter setup with Kailash
- State management patterns
- API client patterns
- WebSocket integration
- Real-time updates

### 12-testing-strategies
**Purpose**: 3-tier testing with NO MOCKING

**Testing Tiers**:
```
Tier 1 (Unit):
  - Mock ALLOWED
  - Fast, isolated
  - Individual functions

Tier 2 (Integration):
  - NO MOCKING (MANDATORY)
  - Real services
  - API endpoints, database

Tier 3 (E2E):
  - NO MOCKING (MANDATORY)
  - Full system
  - User workflows
```

**Key Skills** (12+ skills):
- Tier selection guidance
- Unit test patterns
- Integration test setup
- E2E test frameworks
- Real infrastructure testing
- Test organization
- Coverage requirements

### 13-architecture-decisions
**Purpose**: Framework and technology selection

**Decision Guides** (8+ skills):
- Core SDK vs DataFlow vs Nexus vs Kaizen
- AsyncLocalRuntime vs LocalRuntime
- PostgreSQL vs SQLite vs MySQL
- Node selection guide
- Test tier selection

### 14-code-templates
**Purpose**: Production-ready templates

**Templates**:
- Basic workflow template
- Cyclic workflow template
- Custom node template
- MCP server template
- Unit test template
- Integration test template
- E2E test template

### 15-error-troubleshooting
**Purpose**: Error patterns and debugging

**Error Coverage** (20+ error codes):
- Nexus blocking issues
- Connection parameter errors
- Runtime execution errors
- Cycle convergence problems
- Missing `.build()` calls
- Parameter validation errors
- DataFlow template syntax errors

### 16-validation-patterns
**Purpose**: Compliance checking

**Validation Types** (10+ patterns):
- Parameter validation
- DataFlow pattern validation
- Connection validation
- Absolute import validation
- Workflow structure validation
- Security validation

### 17-gold-standards
**Purpose**: Mandatory best practices

**Standards Covered**:
1. Absolute imports (MANDATORY)
2. Parameter passing patterns
3. Error handling standards
4. NO MOCKING policy (Tiers 2-3)
5. Workflow design standards
6. Custom node development
7. Security best practices
8. Documentation standards
9. Test creation standards

## Skill Organization Principles

### Entry Point Pattern
Every skill category has:
```
skill-category/
├── SKILL.md              # Entry point with description and key patterns
├── detailed-topic-1.md
├── detailed-topic-2.md
└── ...
```

### Reference Integration
Skills reference sdk-users documentation:
```markdown
For complete details, see:
- `sdk-users/apps/dataflow/CLAUDE.md` (89KB comprehensive guide)
- `sdk-users/3-development/testing/CLAUDE.md` (3-tier testing)
```

### Skill Invocation
Skills are invoked through the main CLAUDE.md skill configuration:
```yaml
---
name: 01-core-sdk
description: WorkflowBuilder, nodes, runtime patterns, parameter passing...
---
```

## Comparison with Everything Claude Code

| Aspect | Everything CC | Kailash Setup |
|--------|---------------|---------------|
| Total Skills | 24 | 17 categories (100+) |
| Documentation | Standalone | Integrated with sdk-users |
| Framework-Specific | No | Yes (DataFlow, Nexus, Kaizen, MCP) |
| Industry Patterns | No | Yes (finance, healthcare, etc.) |
| Error Guides | Limited | Comprehensive (20+ error codes) |
| Testing | TDD only | 3-tier with NO MOCKING |
| Frontend | React only | React + Flutter |
| AI Development | No | Kaizen agent patterns |

## Unique Strengths

1. **Deep Framework Integration**: Skills map directly to sdk-users documentation
2. **Comprehensive Error Coverage**: 20+ error codes with solutions
3. **Industry Patterns**: Finance, healthcare, logistics, manufacturing, retail
4. **NO MOCKING Policy**: Real infrastructure testing in Tiers 2-3
5. **Multi-Platform**: React + Flutter frontend integration
6. **AI-Native**: Full Kaizen agent development patterns
