# 05 - MCP Configuration Plan

## Overview

**Priority**: MEDIUM (Week 3)
**Impact**: Proper context management, avoid 200k→70k context loss

## The Context Problem

**Without MCP limits**:
- 200k total context
- 20+ MCPs enabled
- Each MCP: ~2-5k tokens
- Result: ~70k usable (65% loss!)

**With proper configuration**:
- Tiered MCP sets
- Clear context warnings
- Project-appropriate selection

## What Everything Claude Code Has

### MCP Configuration (15+ servers)
```
mcp-configs/
├── README.md (context warnings)
├── development.json
├── production.json
└── minimal.json
```

### Explicit Limits
- 20-30 MCPs configured maximum
- <10 enabled per project
- <80 tools active

## Plan Contents

- `01-tiered-configs.md` - Create minimal/dev/full configurations
- `02-context-warnings.md` - Documentation and limits

## Files to Create

```
mcp-configs/
├── README.md           # Context warnings and selection guide
├── kailash-minimal.json  # GitHub + memory (~15k)
├── kailash-dev.json      # + filesystem (~25k)
└── kailash-full.json     # + database + deploy (~35k)
```

## Success Criteria

| Metric | Current | Target |
|--------|---------|--------|
| MCP configurations | 0 | 3 |
| Context warnings documented | No | Yes |
| Safe limits documented | No | Yes |

## MCP Evaluation Results

From philosophy guide evaluation:

**sdk-users as MCP: NOT RECOMMENDED**
- Static content better served via skills + Read tool
- Context cost (~3,000+ tokens) outweighs benefits
- Skills + fallback to sdk-users is sufficient

## Configuration Details

### Minimal (~15k context cost)
- **github**: PR/issue management
- **memory**: Session persistence

### Development (~25k context cost)
- Everything in minimal
- **filesystem**: File operations

### Full Stack (~35k context cost)
- Everything in development
- **postgres**: Database operations
- **vercel/railway**: Deployment (optional)
