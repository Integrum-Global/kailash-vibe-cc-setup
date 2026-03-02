# MCP Server Philosophy and Quality Guide

## First Principles

### What MCPs ARE
- **Tool Bridges**: Connect Claude to external systems
- **Capability Extensions**: Add abilities Claude doesn't have natively
- **Structured Interfaces**: Provide typed, documented tool access
- **Session Contexts**: Maintain state across operations

### What MCPs are NOT
- **Documentation Replacements**: Not for static information retrieval
- **Context-Free**: Always consume context budget
- **Unlimited**: Too many MCPs degrade performance

## The MCP Contract

```
INPUT: Claude needs to interact with external system
       ↓
MCP RESPONSIBILITIES:
1. Expose tools with clear signatures
2. Validate inputs before execution
3. Handle errors gracefully
4. Return structured results
5. Manage resources efficiently
       ↓
OUTPUT: Tool results or clear error messages
```

## Context Budget Impact (CRITICAL)

### The 200k Problem
```
TOTAL CONTEXT: 200,000 tokens

WITHOUT MCPs:
├── System prompt: ~5,000
├── CLAUDE.md: ~3,000
├── Conversation: ~192,000 available
└── EFFECTIVE: ~192,000 tokens

WITH 20+ MCPs:
├── System prompt: ~5,000
├── CLAUDE.md: ~3,000
├── MCP definitions: ~125,000 (!!!)
├── Conversation: ~67,000 available
└── EFFECTIVE: ~67,000 tokens (65% LOSS)
```

### Safe Limits
| Metric | Maximum | Recommended |
|--------|---------|-------------|
| Configured MCPs | 30 | 15-20 |
| Enabled per project | 10 | 5-7 |
| Active tools | 80 | 40-50 |
| Context per MCP | ~5,000 | <3,000 |

## MCP Categories

### 1. Source Control (Essential)
```json
{
  "github": {
    "type": "http",
    "url": "https://api.githubcopilot.com/mcp/"
  }
}
```
- PRs, issues, actions
- Context cost: ~8,000 tokens

### 2. Database (Project-Specific)
```json
{
  "postgres": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-postgres"]
  }
}
```
- Query, schema, data
- Context cost: ~5,000 tokens

### 3. Memory/Persistence (Essential)
```json
{
  "memory": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-memory"]
  }
}
```
- Session persistence
- Context cost: ~2,000 tokens

### 4. Deployment (Project-Specific)
```json
{
  "vercel": {
    "type": "http",
    "url": "https://vercel.com/mcp/"
  }
}
```
- Deploy, logs, domains
- Context cost: ~4,000 tokens

### 5. Documentation (Situational)
```json
{
  "context7": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "context7-mcp"]
  }
}
```
- External doc retrieval
- Context cost: ~3,000 tokens

## Quality Criteria

### When to Use MCP
```
USE MCP when:
├── Need live data (API calls, queries)
├── Need to perform actions (deploy, commit)
├── State changes required
├── External system interaction
└── Claude can't do it natively

DON'T USE MCP when:
├── Static information retrieval
├── Internal documentation lookup
├── Pattern/template retrieval
├── Information that rarely changes
└── Can use CLI commands instead
```

### MCP vs CLI Decision
```
PREFER CLI (via Bash) when:
├── Mature CLI exists (gh, npm, docker)
├── One-off operations
├── Lower context cost
└── Better error messages

PREFER MCP when:
├── Structured data needed
├── Multiple related operations
├── Session state required
└── Tool discovery matters
```

## Kailash-Specific MCP Evaluation

### sdk-users as MCP: EVALUATION

**Question**: Should sdk-users documentation be served via MCP?

#### Arguments FOR MCP:
1. **Semantic Search**: MCP could enable vector search over docs
2. **Dynamic Updates**: Docs could update without session restart
3. **Structured Retrieval**: Get specific sections, not whole files
4. **Cross-Reference**: Follow links between documents

#### Arguments AGAINST MCP:
1. **Context Cost**: MCP definition adds ~3,000+ tokens
2. **Static Content**: Docs don't change during session
3. **Already Accessible**: Read tool can access any file
4. **Duplication**: Would duplicate existing skill functionality
5. **Latency**: MCP call slower than direct file read

#### Analysis Matrix
| Criterion | MCP Approach | Current Approach | Winner |
|-----------|-------------|------------------|--------|
| Context cost | High (~3,000+) | Low (on-demand) | Current |
| Access speed | Slower (tool call) | Faster (direct) | Current |
| Search capability | Semantic | Grep/pattern | MCP |
| Freshness | Real-time | Session-bound | Tie |
| Complexity | Higher | Lower | Current |

#### RECOMMENDATION: NO to sdk-users MCP

**Rationale**:
1. **Context budget**: 3,000+ tokens for marginal benefit
2. **Existing capability**: Skills + Read tool already work well
3. **Static nature**: Docs don't benefit from dynamic retrieval
4. **Complexity**: Adds maintenance burden without clear value

**Alternative Improvements**:
1. Better skill indexing (current approach)
2. Improved sdk-users directory structure
3. Better cross-references in skills
4. Agent knowledge of doc locations

### Recommended MCP Configuration for Kailash

#### Minimal (5 tools, ~15k context)
```json
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    },
    "memory": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"]
    }
  }
}
```

#### Development (7 tools, ~25k context)
```json
{
  "mcpServers": {
    "github": { "...": "..." },
    "memory": { "...": "..." },
    "postgres": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "${DATABASE_URL}"
      }
    }
  }
}
```

#### Production (10 tools, ~35k context)
```json
{
  "mcpServers": {
    "github": { "...": "..." },
    "memory": { "...": "..." },
    "postgres": { "...": "..." },
    "vercel": {
      "type": "http",
      "url": "https://vercel.com/mcp/",
      "headers": {
        "Authorization": "Bearer ${VERCEL_TOKEN}"
      }
    },
    "sentry": {
      "type": "http",
      "url": "https://sentry.io/mcp/"
    }
  }
}
```

## Custom MCP Development

### When to Build Custom MCP

```
BUILD CUSTOM when:
├── No existing MCP covers the use case
├── Proprietary system integration needed
├── Custom business logic required
├── Performance optimization needed
└── Security constraints apply

DON'T BUILD when:
├── Existing MCP works
├── CLI alternative exists
├── One-time need
├── Simple API wrapper sufficient
└── Context budget concerns
```

### Kailash MCP Framework

If custom MCP needed, use Kailash's built-in MCP support:

```python
from kailash.mcp_server import MCPServer, tool, resource

class KailashDocsServer(MCPServer):
    """Custom MCP for Kailash documentation."""

    @tool(description="Search Kailash documentation")
    async def search_docs(self, query: str) -> list[dict]:
        """Semantic search over sdk-users."""
        # Implementation
        pass

    @resource(uri="docs://dataflow", description="DataFlow guide")
    async def dataflow_guide(self) -> str:
        """Return DataFlow documentation."""
        # Implementation
        pass
```

**Note**: This is NOT recommended for sdk-users (see evaluation above), but shows the pattern if custom MCP is needed for other purposes.

## Quality Checklist

### Configuration Quality
- [ ] Context budget calculated (<30% of total)
- [ ] Only necessary MCPs enabled
- [ ] Environment variables properly configured
- [ ] Authentication secure (no hardcoded secrets)

### Operational Quality
- [ ] MCP servers start reliably
- [ ] Error handling is graceful
- [ ] Timeouts are appropriate
- [ ] Resource cleanup on session end

### Anti-Patterns Avoided
- [ ] No "enable everything" approach
- [ ] No static doc serving via MCP
- [ ] No MCP for CLI-capable operations
- [ ] No secrets in configuration

## Current Gap

Kailash setup has **NO** MCP configurations.

**Recommendation**: Create `mcp-configs/` directory with:
1. `README.md` with context warnings
2. `kailash-minimal.json` (GitHub + memory)
3. `kailash-dev.json` (+ database)
4. `kailash-prod.json` (+ deployment)

**Priority**: Implement as Priority 3 (after hooks and agents).
