# Everything Claude Code - Repository Overview

**Repository**: `./repos/training/everything-claude-code`
**Author**: Affaan Mustafa (Anthropic x Forum Ventures Hackathon Winner, September 2025)
**Version**: v1.2.0 (as of plugin.json)
**Total Files**: 242 files

## Executive Summary

Everything Claude Code is a production-ready Claude Code plugin containing battle-tested configurations evolved over 10+ months of intensive daily use. It represents a comprehensive approach to configuring Claude Code for professional software development.

## Core Philosophy

The repository embodies several key principles:

1. **Specialization over Generalization**: Rather than one all-purpose configuration, it provides 12 specialized agents, 24 skills, and 23 commands
2. **Continuous Learning**: Implements a sophisticated v2 learning system that observes tool usage and evolves instincts into skills
3. **Mandatory Quality Gates**: TDD (80%+ coverage), security reviews, and code reviews are non-negotiable
4. **Context Conservation**: Aggressive management of context window through strategic compaction and limited MCP usage

## Repository Statistics

| Component | Count | Purpose |
|-----------|-------|---------|
| Agents | 12 | Specialized subagents with focused scopes |
| Skills | 24 | Workflow definitions and domain knowledge |
| Commands | 23 | Slash commands for quick actions |
| Rules | 8 | Always-follow guidelines |
| Hooks | 6+ types | Event-driven automation |
| MCP Servers | 15+ | External tool integrations |

## Installation Methods

### Plugin Installation (Recommended)
```bash
/plugin marketplace add affaan-m/everything-claude-code
/plugin install everything-claude-code@everything-claude-code
```

### Manual Installation
```bash
git clone https://github.com/affaan-m/everything-claude-code.git
cp agents/*.md ~/.claude/agents/
cp rules/*.md ~/.claude/rules/
cp commands/*.md ~/.claude/commands/
cp -r skills/* ~/.claude/skills/
```

**Note**: Rules are NOT distributed via plugins (upstream limitation in Claude Code).

## Key Innovation: Continuous Learning v2

The repository's most sophisticated feature is its learning system:

```
Session Activity → Hooks (100% reliable) → observations.jsonl →
Observer Agent (Haiku) → Pattern Detection → Instincts (0.3-0.9 confidence) →
Clustering → Skills/Commands/Agents
```

This allows the system to learn from actual usage patterns and evolve into more refined configurations.

## Critical Context Management

**Warning**: Don't enable all MCPs at once.
- 200k context → ~70k with too many MCPs
- Rule: 20-30 MCPs configured, <10 enabled per project, <80 tools active

## Documentation Quality

The repository includes:
- **README.md**: 506 lines - Installation and overview
- **the-shortform-guide.md**: 431 lines - Setup and foundations
- **the-longform-guide.md**: 100+ lines - Advanced patterns
- **Traditional Chinese translations**: Complete zh-TW documentation
