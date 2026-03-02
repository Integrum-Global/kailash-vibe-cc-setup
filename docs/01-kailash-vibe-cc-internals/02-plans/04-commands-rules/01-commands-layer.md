# Commands Layer Implementation

## Why Commands Matter

Skills are referenced by numbered names (`/01-core-sdk`), which:
- Requires remembering numbers
- Not intuitive for new users
- Harder to type

Commands provide memorable aliases.

## Command Template

```markdown
---
name: [command-name]
description: [Brief description] (max 80 chars)
---

# /[command-name]

[One sentence explaining what this command does]

Invokes the **[skill-name]** skill for [specific purpose].

## Usage
\`\`\`
/[command-name]
\`\`\`

## Related Commands
- `/[related]` - [Description]
```

## Commands to Create

### 1. /sdk → /01-core-sdk

**File**: `.claude/commands/sdk.md`

```markdown
---
name: sdk
description: Core SDK patterns and workflow basics
---

# /sdk

Quick access to Kailash Core SDK patterns and fundamentals.

Invokes the **01-core-sdk** skill for workflow building, node patterns, and runtime execution.

## Usage
\`\`\`
/sdk
\`\`\`

## What You'll Get
- WorkflowBuilder patterns
- 4-param node pattern
- Runtime execution
- Connection patterns
- Error handling

## Related Commands
- `/db` - DataFlow database operations
- `/api` - Nexus API deployment
- `/ai` - Kaizen AI agents
```

### 2. /db → /02-dataflow

**File**: `.claude/commands/db.md`

```markdown
---
name: db
description: DataFlow database operations and patterns
---

# /db

Quick access to DataFlow database patterns and CRUD operations.

Invokes the **02-dataflow** skill for database models, auto-generated nodes, and data operations.

## Usage
\`\`\`
/db
\`\`\`

## What You'll Get
- Model definition patterns
- 11 auto-generated nodes per model
- CRUD operations
- Bulk operations
- Critical gotchas

## Related Commands
- `/sdk` - Core SDK fundamentals
- `/api` - Nexus for API exposure
- `/test` - Testing DataFlow code
```

### 3. /api → /03-nexus

**File**: `.claude/commands/api.md`

```markdown
---
name: api
description: Nexus multi-channel platform deployment
---

# /api

Quick access to Nexus multi-channel deployment patterns.

Invokes the **03-nexus** skill for API, CLI, and MCP deployment.

## Usage
\`\`\`
/api
\`\`\`

## What You'll Get
- Zero-config deployment
- API + CLI + MCP simultaneously
- Unified sessions
- Health monitoring
- Plugin system

## Related Commands
- `/sdk` - Core SDK fundamentals
- `/db` - DataFlow for database
- `/mcp` - MCP specifics
```

### 4. /ai → /04-kaizen

**File**: `.claude/commands/ai.md`

```markdown
---
name: ai
description: Kaizen AI agent framework patterns
---

# /ai

Quick access to Kaizen AI agent framework patterns.

Invokes the **04-kaizen** skill for signature-based agents, multi-agent coordination, and enterprise AI.

## Usage
\`\`\`
/ai
\`\`\`

## What You'll Get
- BaseAgent architecture
- Signature-based programming
- Multi-agent coordination
- RAG patterns
- Prompt optimization

## Related Commands
- `/sdk` - Core SDK fundamentals
- `/mcp` - MCP for tool integration
- `/test` - Testing AI agents
```

### 5. /test → /12-testing-strategies

**File**: `.claude/commands/test.md`

```markdown
---
name: test
description: 3-tier testing strategy with NO MOCKING
---

# /test

Quick access to Kailash testing strategy and patterns.

Invokes the **12-testing-strategies** skill for 3-tier testing with NO MOCKING policy.

## Usage
\`\`\`
/test
\`\`\`

## What You'll Get
- 3-tier testing (Unit/Integration/E2E)
- NO MOCKING in Tiers 2-3
- Test organization
- Real infrastructure testing
- Coverage requirements

## Related Commands
- `/validate` - Gold standards compliance
- `/sdk` - Core SDK patterns to test
```

### 6. /validate → /17-gold-standards

**File**: `.claude/commands/validate.md`

```markdown
---
name: validate
description: Gold standards compliance checking
---

# /validate

Quick access to Kailash gold standards and compliance validation.

Invokes the **17-gold-standards** skill for mandatory patterns and validation.

## Usage
\`\`\`
/validate
\`\`\`

## What You'll Get
- Absolute imports requirement
- 4-param node pattern
- NO MOCKING policy
- Error handling standards
- Documentation standards

## Related Commands
- `/test` - Testing patterns
- `/sdk` - Core patterns to validate
```

## Additional Commands (Future)

| Command | Points To | Purpose |
|---------|-----------|---------|
| `/mcp` | 05-mcp | MCP integration |
| `/cheat` | 06-cheatsheets | Quick references |
| `/deploy` | 10-deployment-git | Deployment patterns |
| `/frontend` | 11-frontend-integration | Frontend patterns |
| `/errors` | 15-error-troubleshooting | Error solutions |

## Implementation Steps

1. Create `.claude/commands/` directory
2. Create each command file
3. Test each command in Claude session
4. Verify skill invocation works

## Verification

```bash
# After creating commands:
ls -la .claude/commands/

# In Claude session:
# Type "/sdk" and verify 01-core-sdk content loads
# Type "/db" and verify 02-dataflow content loads
# etc.
```
