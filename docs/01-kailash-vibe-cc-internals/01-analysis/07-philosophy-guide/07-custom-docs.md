# Custom Documentation Philosophy and Quality Guide

## First Principles

### What Custom Docs ARE
- **Single Source of Truth**: Canonical reference for "what it is" and "how to use it"
- **Developer-Focused**: Written for implementers, not marketers
- **Complete Coverage**: All features, patterns, edge cases documented
- **Searchable**: Organized for both human and AI navigation

### What Custom Docs are NOT
- **Status Reports**: No progress updates, changelogs in main docs
- **Marketing Material**: No promotional language
- **Duplicate Content**: No repeated information across files
- **Tutorials**: Conceptual learning belongs elsewhere

## The Documentation Contract

```
INPUT: Developer needs to understand or implement feature
       ↓
DOCUMENTATION RESPONSIBILITIES:
1. Explain WHAT the feature is
2. Show HOW to use it
3. Document ALL parameters/options
4. Provide working EXAMPLES
5. List known LIMITATIONS
       ↓
OUTPUT: Developer can implement without guessing
```

## The sdk-users Philosophy

### Core Principle: 80/15/5 Rule
```
SKILL (80% of lookups):
├── Most common patterns
├── Critical gotchas
├── Quick examples
└── Doc references

sdk-users (15% of lookups):
├── Complete API reference
├── All parameters documented
├── Edge cases covered
├── Full examples

External (5% of lookups):
├── Theoretical background
├── Academic references
├── Community discussions
└── Issue discussions
```

### Information Flow
```
User Request
     │
     ▼
┌─────────────────────────────────────┐
│             AGENT                    │
│  (Knows WHAT to look for WHERE)     │
└─────────────────────────────────────┘
     │
     ├──► SKILL (Quick patterns)
     │         │
     │         ▼
     │    ┌────────────────────┐
     │    │  Pattern found?    │
     │    └────────────────────┘
     │         │
     │    Yes  │  No
     │    ▼    │
     │  DONE   │
     │         ▼
     └──► sdk-users (Full docs)
               │
               ▼
          ┌────────────────────┐
          │  Documentation     │
          │  found?            │
          └────────────────────┘
               │
          Yes  │  No
          ▼    │
        DONE   │
               ▼
          External search
```

## Structure Standards

### sdk-users Directory Structure
```
sdk-users/
├── CLAUDE.md                    # Entry point for AI navigation
├── apps/                        # Framework-specific guides
│   ├── dataflow/
│   │   ├── CLAUDE.md           # Complete DataFlow reference
│   │   ├── guides/             # How-to guides
│   │   └── examples/           # Working examples
│   ├── nexus/
│   │   └── CLAUDE.md
│   └── kaizen/
│       └── CLAUDE.md
├── 3-development/               # Cross-cutting development topics
│   ├── testing/
│   │   └── CLAUDE.md           # Testing strategy
│   └── deployment/
│       └── CLAUDE.md
├── 7-gold-standards/            # Mandatory patterns
│   └── CLAUDE.md
└── guides/                      # Integration guides
    └── CLAUDE.md
```

### CLAUDE.md Structure (Framework Guide)
```markdown
# [Framework Name] Complete Reference

## Quick Start
[Minimal working example - 10 lines max]

## Installation
[Package installation]

## Core Concepts
[What it is, how it works]

## API Reference
[All classes, methods, parameters]

## Patterns
[Common patterns with examples]

## Configuration
[All configuration options]

## Troubleshooting
[Common errors and solutions]

## Migration
[Upgrading from previous versions]

## Changelog
[Version history - keep brief]
```

## Quality Criteria

### Documentation Completeness
| Section | Required | Optional |
|---------|----------|----------|
| Quick Start | ✓ | |
| Installation | ✓ | |
| Core Concepts | ✓ | |
| API Reference | ✓ | |
| Patterns | ✓ | |
| Configuration | ✓ | |
| Troubleshooting | ✓ | |
| Migration | | ✓ |
| Changelog | | ✓ |

### Content Quality Metrics
```
GOOD documentation:
├── Code examples: Tested, working
├── Parameters: All documented
├── Return types: Specified
├── Exceptions: Listed
├── Edge cases: Covered
└── Cross-references: Present

POOR documentation:
├── "See source code"
├── Parameters: "Various options"
├── Examples: Pseudo-code only
├── Edge cases: "Handle accordingly"
└── Outdated: Doesn't match code
```

## Quality Checklist

### Structural Quality
- [ ] CLAUDE.md exists as entry point
- [ ] All sections present (see template)
- [ ] Logical organization (concept → detail)
- [ ] Cross-references working

### Content Quality
- [ ] All code examples tested
- [ ] All parameters documented
- [ ] All return types specified
- [ ] Common errors covered
- [ ] No placeholder content

### Maintenance Quality
- [ ] No outdated information
- [ ] Version numbers accurate
- [ ] Links not broken
- [ ] Examples run against current API

### Anti-Patterns Avoided
- [ ] No marketing language
- [ ] No status/progress updates in docs
- [ ] No duplicate content
- [ ] No "TODO" or "FIXME" in docs

## Kailash sdk-users Evaluation

### Current State: Strong

**Strengths:**
- Comprehensive coverage (DataFlow: 89KB, Kaizen: 1,900+ lines)
- Single source of truth pattern
- CLAUDE.md entry points
- Working examples included

**Issues Found:**

#### 1. Missing Root Navigation
No root-level CLAUDE.md explaining sdk-users structure.

**Add** `sdk-users/CLAUDE.md`:
```markdown
# Kailash SDK Documentation

## Navigation

### By Framework
- `apps/dataflow/CLAUDE.md` - Database operations
- `apps/nexus/CLAUDE.md` - Multi-channel platform
- `apps/kaizen/CLAUDE.md` - AI agents

### By Topic
- `3-development/testing/CLAUDE.md` - Testing strategy
- `7-gold-standards/CLAUDE.md` - Mandatory patterns

### Quick Decision
- Database work? → DataFlow
- API/platform? → Nexus
- AI agents? → Kaizen
- Testing? → 3-development/testing
```

#### 2. Inconsistent Depth
DataFlow: Very detailed (89KB)
Nexus: Less detailed
Kaizen: Moderate (1,900 lines)

**Recommendation**: Standardize to same depth level.

#### 3. Missing Version Pinning
Documentation doesn't always specify which version it covers.

**Add to each CLAUDE.md header:**
```markdown
---
framework: DataFlow
version: 0.10.15
last_updated: 2026-01-30
---
```

## Documentation Writing Guide

### Voice and Tone
```
USE:
├── Active voice ("Create a model")
├── Second person ("You can configure")
├── Present tense ("Returns a list")
├── Direct instructions ("Set the parameter")

AVOID:
├── Passive voice ("A model is created")
├── First person ("We recommend")
├── Future tense ("Will return")
├── Hedging ("You might want to")
```

### Code Examples
```python
# GOOD: Complete, runnable, with context
from dataflow import DataFlow
from dataflow.decorators import db

db = DataFlow(database_url="postgresql://...")

@db.model
class User:
    id: int
    name: str
    email: str

# Creates User_CREATE, User_READ, etc. nodes
db.initialize()

# BAD: Incomplete, won't run
# Create a model
class User:
    # add fields
    pass
```

### Parameter Documentation
```markdown
## method_name(param1, param2, **kwargs)

Brief description of what the method does.

**Parameters:**
- `param1` (str): Description. Required.
- `param2` (int, optional): Description. Defaults to 10.
- `**kwargs`: Additional options:
  - `option1` (bool): Description. Default: False.
  - `option2` (str): Description. Default: "value".

**Returns:**
- `ReturnType`: Description of return value.

**Raises:**
- `ValueError`: When param1 is empty.
- `ConnectionError`: When database unavailable.

**Example:**
```python
result = method_name("value", 5, option1=True)
```
```

## Template: Framework CLAUDE.md

```markdown
---
framework: [Framework Name]
version: [X.Y.Z]
last_updated: [YYYY-MM-DD]
---

# [Framework Name] Complete Reference

## Overview
[2-3 sentences: What it is, why use it]

## Quick Start
```python
[Minimal working example - 10 lines max]
```

## Installation
```bash
pip install kailash-[framework]
```

**Requirements:**
- Python 3.9+
- [Other requirements]

## Core Concepts

### [Concept 1]
[Explanation with example]

### [Concept 2]
[Explanation with example]

## API Reference

### [Class/Module 1]

#### method_name(params)
[Full documentation per template above]

### [Class/Module 2]
[...]

## Patterns

### [Pattern 1]: [Name]
**Use when:** [Condition]

```python
[Working example]
```

### [Pattern 2]: [Name]
[...]

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| option1 | str | "default" | What it does |
| option2 | int | 10 | What it does |

## Troubleshooting

### Error: [ErrorName]
**Cause:** [Why it happens]
**Solution:** [How to fix]

### Error: [AnotherError]
[...]

## Migration from [Previous Version]

### Breaking Changes
1. [Change 1]
2. [Change 2]

### Upgrade Steps
1. [Step 1]
2. [Step 2]

## Related Documentation
- [Link to related doc]
- [Link to another related doc]
```

## Improvement Actions

### Immediate
1. Create `sdk-users/CLAUDE.md` root navigation
2. Add version frontmatter to all framework docs
3. Verify all code examples run

### Short-term
1. Standardize documentation depth across frameworks
2. Add troubleshooting sections where missing
3. Cross-reference between related docs

### Long-term
1. Implement doc testing in CI
2. Add automated freshness checks
3. Create doc contribution guide
