# Tiered MCP Configurations

## Overview

Three tiers of MCP configuration for different project needs:

| Tier | MCPs | Context Cost | Use Case |
|------|------|--------------|----------|
| Minimal | 2 | ~15k | Basic projects |
| Development | 3 | ~25k | Active development |
| Full | 5 | ~35k | Full-stack projects |

## Configuration Files

### 1. kailash-minimal.json

**File**: `mcp-configs/kailash-minimal.json`

**Use when**:
- Context efficiency is critical
- Only need GitHub and session persistence
- Simple projects

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "description": "Minimal MCP configuration for Kailash projects. Context cost: ~15k tokens.",
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "description": "GitHub operations: PRs, issues, actions"
    },
    "memory": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
      "description": "Session persistence across restarts"
    }
  }
}
```

### 2. kailash-dev.json

**File**: `mcp-configs/kailash-dev.json`

**Use when**:
- Active development
- Need filesystem access
- Building workflows

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "description": "Development MCP configuration for Kailash projects. Context cost: ~25k tokens.",
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "description": "GitHub operations: PRs, issues, actions"
    },
    "memory": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
      "description": "Session persistence across restarts"
    },
    "filesystem": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "--root", "."],
      "description": "File system operations in project root"
    }
  }
}
```

### 3. kailash-full.json

**File**: `mcp-configs/kailash-full.json`

**Use when**:
- Full-stack development
- Database operations needed
- Deployment integration

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "description": "Full-stack MCP configuration for Kailash projects. Context cost: ~35k tokens.",
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "description": "GitHub operations: PRs, issues, actions"
    },
    "memory": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
      "description": "Session persistence across restarts"
    },
    "filesystem": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "--root", "."],
      "description": "File system operations in project root"
    },
    "postgres": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "POSTGRES_URL": "${DATABASE_URL}"
      },
      "description": "PostgreSQL database operations"
    },
    "sequential-thinking": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
      "description": "Extended reasoning capabilities"
    }
  }
}
```

## Usage Instructions

### Using a Configuration

1. Copy desired config to `~/.claude.json`:
```bash
cp mcp-configs/kailash-dev.json ~/.claude.json
```

2. Or reference in project:
```bash
claude --mcp-config mcp-configs/kailash-dev.json
```

### Switching Configurations

```bash
# Switch to minimal (context efficiency)
cp mcp-configs/kailash-minimal.json ~/.claude.json

# Switch to full (database work)
cp mcp-configs/kailash-full.json ~/.claude.json
```

### Customizing

Start with a tier, add project-specific MCPs:

```json
{
  "mcpServers": {
    // ... base config ...
    "my-custom-mcp": {
      "type": "stdio",
      "command": "my-mcp-server",
      "args": []
    }
  }
}
```

## Context Budget Planning

| Configuration | MCP Cost | System | CLAUDE.md | Available |
|---------------|----------|--------|-----------|-----------|
| No MCPs | 0 | ~5k | ~3k | ~192k |
| Minimal | ~15k | ~5k | ~3k | ~177k |
| Development | ~25k | ~5k | ~3k | ~167k |
| Full | ~35k | ~5k | ~3k | ~157k |

## Validation

```bash
# Verify JSON syntax
node -e "JSON.parse(require('fs').readFileSync('mcp-configs/kailash-minimal.json'))"
node -e "JSON.parse(require('fs').readFileSync('mcp-configs/kailash-dev.json'))"
node -e "JSON.parse(require('fs').readFileSync('mcp-configs/kailash-full.json'))"

# Start Claude with config
claude --mcp-config mcp-configs/kailash-dev.json

# Check context usage
# In session: /context
```
