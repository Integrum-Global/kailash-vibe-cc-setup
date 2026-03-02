# Kailash Vibe CC Setup - Repository Overview

**Repository**: `.`
**Purpose**: AI-assisted development platform for Kailash SDK ecosystem
**Focus**: Framework-specific development with specialized subagents

## Executive Summary

The Kailash Vibe CC Setup is a comprehensive Claude Code configuration designed specifically for the Kailash SDK ecosystem. It provides:

- **22 specialized subagents** covering all aspects of SDK development
- **17 skill categories** with 100+ individual skills referencing sdk-users documentation
- **11 development guides** for complex implementation patterns
- **Complete SOP** in instructions/ for structured development workflow
- **Full SDK documentation** in sdk-users/ as single source of truth

## Core Philosophy

The setup embodies a **framework-first approach**:

1. **Never Build From Scratch**: Always use Kailash SDK frameworks (Core SDK, DataFlow, Nexus, Kaizen)
2. **Specialist Delegation**: Always consult framework-specific specialists before implementation
3. **Test-First Development**: NO MOCKING policy in Tiers 2-3 (real infrastructure required)
4. **Evidence-Based Progress**: File:line references for traceability

## Repository Statistics

| Component | Count | Purpose |
|-----------|-------|---------|
| Agents | 22 | Specialized subagents with framework expertise |
| Skills | 17 categories (100+) | Instant answers and pattern lookups |
| Guides | 11 | Complex implementation patterns |
| SOP Phases | 5 | Complete development workflow |
| SDK Docs | Complete | Full Kailash SDK reference |

## Configuration Structure

```
kailash-vibe-cc-setup/
├── CLAUDE.md                    # Master coordination (273 lines)
├── .claude/
│   ├── settings.local.json      # Permissions (git, web, python, bash)
│   ├── agents/                  # 22 specialized subagents
│   │   ├── frameworks/          # Framework specialists (4)
│   │   ├── frontend/            # Frontend specialists (4)
│   │   └── management/          # Project management (3)
│   ├── skills/                  # 17 skill categories (100+ skills)
│   └── guides/                  # 11 implementation guides
├── instructions/                # Complete SOP
│   ├── 00-manual_checklist/
│   ├── 01-analysis/
│   ├── 02-plans/
│   ├── 03-implement/
│   ├── 04-codegen-instructions/
│   └── 05-validation/
└── sdk-users/                   # Complete SDK documentation
    └── apps/                    # Framework-specific guides
        ├── dataflow/            # 89KB comprehensive guide
        ├── nexus/               # Multi-channel platform
        └── kaizen/              # AI agent framework
```

## Framework Hierarchy

```
Core SDK (foundational)
├── 110+ production nodes
├── WorkflowBuilder
├── LocalRuntime & AsyncLocalRuntime
└── MCP integration

DataFlow (built on Core SDK)
├── @db.model decorator → 11 auto-generated nodes
│   ├── CRUD (7): CREATE, READ, UPDATE, DELETE, LIST, UPSERT, COUNT
│   └── Bulk (4): BULK_CREATE, BULK_UPDATE, BULK_DELETE, BULK_UPSERT
└── Multi-database support (PostgreSQL, MySQL, SQLite)

Nexus (built on Core SDK)
├── Zero-config multi-channel deployment
├── API + CLI + MCP unified sessions
└── DataFlow integration

Kaizen (built on Core SDK)
├── Signature-based AI agents
├── Multi-agent coordination
└── Multi-modal processing
```

## Critical Rules

From CLAUDE.md:

1. **Always use Kailash SDK frameworks** - Never build from scratch
2. **Always use specialist subagents** - Consult framework experts
3. **Always load .env first** - Before any operation
4. **Always use `runtime.execute(workflow.build())`** - Never `workflow.execute(runtime)`
5. **NO MOCKING in Tiers 2-3** - Real infrastructure required
6. **String-based node IDs** - `workflow.add_node("NodeName", "id", {})`

## Development Workflow Phases

```
1. Analysis    → deep-analyst, requirements-analyst, sdk-navigator, framework-advisor
2. Planning    → todo-manager, gh-manager, intermediate-reviewer
3. Implementation → tdd-implementer, pattern-expert, framework specialist
4. Testing     → testing-specialist, gold-standards-validator
5. Deployment  → deployment-specialist, git-release-specialist
```

## Key Differentiators

Compared to general-purpose Claude Code configurations:

1. **Framework-Specific**: Deeply integrated with Kailash SDK ecosystem
2. **Documentation-Rich**: 89KB DataFlow guide, 1,900+ lines Kaizen guide
3. **SOP-Driven**: Complete workflow from analysis to validation
4. **Enterprise-Ready**: Multi-database, multi-tenancy, audit trails
5. **AI-Native**: Built-in support for AI agent development (Kaizen)

## Success Factors (Documented)

From CLAUDE.md:

**What Worked Well**:
1. Systematic task completion
2. Test-first development
3. Real infrastructure testing
4. Evidence-based tracking
5. Comprehensive documentation
6. Subagent specialization
7. Manual verification
8. Design system foundation
9. Institutional directives
10. Component reusability

**Lessons Learned**:
1. Documentation early
2. Pattern consistency
3. Incremental validation
4. Comprehensive coverage
5. Design system as foundation
6. Mandatory guides
7. Single import pattern
8. Component showcase
9. Deprecation fixes
10. Real device testing
