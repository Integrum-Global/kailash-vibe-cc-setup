# 02 - Agents Enhancement Plan

## Overview

**Priority**: CRITICAL (Week 1, Days 3-5)
**Current Score**: 8.5/10
**Target Score**: 9.0/10
**Impact**: Complete agent infrastructure with mandatory reviews and quality gates

## Current State Assessment

### Agent Inventory (22 total)

| Category | Count | Location |
|----------|-------|----------|
| Root-level | 7 | `.claude/agents/` |
| Framework specialists | 4 | `.claude/agents/frameworks/` |
| Frontend specialists | 4 | `.claude/agents/frontend/` |
| Management | 3 | `.claude/agents/management/` |
| **Total** | **22** | (was incorrectly documented as 18) |

### Quality Issues Identified

| Issue | Severity | Affected Agents |
|-------|----------|-----------------|
| Missing `tools:` in frontmatter | CRITICAL | All 22 agents |
| Missing `model:` in frontmatter | HIGH | All 22 agents |
| No "Related Agents" section | MEDIUM | All 22 agents |
| No "Full Documentation" section | MEDIUM | All 22 agents |
| Missing security-reviewer | CRITICAL | N/A (doesn't exist) |
| Missing build-fix agent | HIGH | N/A (doesn't exist) |

## What We're Missing from Everything Claude Code

| Component | Everything CC | Kailash | Action |
|-----------|--------------|---------|--------|
| security-reviewer | Yes | No | CREATE |
| build-error-resolver | Yes (minimal diff policy) | No | CREATE as build-fix |
| e2e-runner | Yes | No | CREATE |
| Mandatory code review | Enforced via rules | Implicit | ADD RULES |
| Tool restrictions | Per agent | None | ADD TO FRONTMATTER |

## Files to Create

1. `.claude/agents/security-reviewer.md` - OWASP-based security checks
2. `.claude/agents/build-fix.md` - Minimal diff error resolution
3. `.claude/agents/e2e-runner.md` - Playwright E2E testing

## Files to Modify

All 22 existing agents need:
1. `tools:` field in frontmatter
2. `model:` field in frontmatter
3. "Related Agents" section
4. "Full Documentation" section

## Implementation Plan

See individual files:
- `01-frontmatter-updates.md` - Add tools/model to all agents
- `02-new-agents.md` - security-reviewer, build-fix, e2e-runner
- `03-cross-references.md` - Related Agents sections
- `04-orchestration-rules.md` - Mandatory delegation rules

## Success Criteria

| Metric | Current | Target |
|--------|---------|--------|
| Agents with tools: | 0% | 100% |
| Agents with model: | 0% | 100% |
| Agents with Related Agents | 0% | 100% |
| Security review capability | No | Yes |
| Mandatory code review | No | Yes (via rules) |

## Dependencies

- Hooks infrastructure must be in place for full automation
- Rules must be created for mandatory delegation
