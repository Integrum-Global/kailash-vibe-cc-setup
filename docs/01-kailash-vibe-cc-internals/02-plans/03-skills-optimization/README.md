# 03 - Skills Optimization Plan

## Overview

**Priority**: HIGH (Week 2, Days 1-2)
**Current Score**: 7.8/10
**Target Score**: 9.0/10
**Impact**: Eliminate duplication, improve maintainability

## Current State Assessment

### Skill Inventory (17 categories)

| Category | Has SKILL.md | File Count | Issues |
|----------|--------------|------------|--------|
| 01-core-sdk | NO | 9 | Missing entry point |
| 02-dataflow | NO | 5 | 570 lines (target: 250) |
| 03-nexus | NO | 10 | Missing entry point |
| 04-kaizen | NO | Unknown | Missing entry point |
| 05-mcp | YES | 7 | OK |
| 06-cheatsheets | YES | 60+ | OK |
| 07-development-guides | YES | 25+ | OK |
| 08-nodes-reference | YES | Unknown | OK |
| 09-workflow-patterns | Unknown | Unknown | Needs audit |
| 10-deployment-git | Unknown | Unknown | Needs audit |
| 11-frontend-integration | Unknown | Unknown | Needs audit |
| 12-testing-strategies | Unknown | Unknown | Needs audit |
| 13-architecture-decisions | Unknown | Unknown | Needs audit |
| 14-code-templates | Unknown | Unknown | Needs audit |
| 15-error-troubleshooting | Unknown | Unknown | Needs audit |
| 16-validation-patterns | Unknown | Unknown | Needs audit |
| 17-gold-standards | Unknown | Unknown | Needs audit |

### Quality Issues

| Issue | Severity | Impact |
|-------|----------|--------|
| 4-param pattern in 5+ places | HIGH | Maintenance nightmare |
| DataFlow SKILL.md bloat (570 lines) | HIGH | Slow loading, context waste |
| Missing SKILL.md in 4 categories | MEDIUM | Inconsistent access |
| No Related Skills sections | MEDIUM | Poor navigation |
| Tutorial content in skills | LOW | Should be in sdk-users |

## What Needs to Change

### 1. Deduplication (CRITICAL)

The 4-param pattern appears in:
- `01-core-sdk/`
- `02-dataflow/`
- `08-nodes-reference/`
- `14-code-templates/`
- `17-gold-standards/`

**Solution**: Keep ONLY in `01-core-sdk`, reference elsewhere.

### 2. DataFlow Reduction (HIGH)

Current: 570 lines
Target: 250 lines (56% reduction)

**Content to keep** (250 lines):
- Quick model pattern (20 lines)
- Node operation patterns (100 lines)
- Critical gotchas (50 lines)
- Top 3 examples (60 lines)
- Doc references (20 lines)

**Content to move to sdk-users** (320 lines):
- Installation/setup (80 lines)
- Detailed model definition (40 lines)
- Migration guide (120 lines)
- Extended examples (80 lines)

### 3. Add SKILL.md Entry Points

Create SKILL.md for:
- `01-core-sdk/SKILL.md`
- `02-dataflow/SKILL.md`
- `03-nexus/SKILL.md`
- `04-kaizen/SKILL.md`

### 4. Add Related Skills Sections

Every skill should reference related skills.

## Implementation Plan

See individual files:
- `01-deduplication-plan.md` - Remove 4-param pattern duplication
- `02-dataflow-reduction.md` - 570→250 lines plan
- `03-skill-md-additions.md` - Add SKILL.md to missing categories
- `04-cross-references.md` - Related Skills sections

## Success Criteria

| Metric | Current | Target |
|--------|---------|--------|
| 4-param pattern locations | 5+ | 1 |
| DataFlow SKILL.md lines | 570 | 250 |
| Skills with SKILL.md | 13/17 | 17/17 |
| Skills with Related Skills | 0% | 100% |

## Dependencies

- Complete after hooks infrastructure
- Coordinate with sdk-users updates
