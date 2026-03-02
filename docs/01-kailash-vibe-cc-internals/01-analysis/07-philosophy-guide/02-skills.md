# Skill Philosophy and Quality Guide

## First Principles

### What Skills ARE
- **Task Enablers**: Provide critical information for task completion
- **Pattern Libraries**: Common patterns in easily consumable format
- **Quick References**: Frequently-needed information at fingertips
- **Documentation Bridges**: Point to full docs for edge cases

### What Skills are NOT
- **Policy Enforcers**: Should not dictate workflow decisions (that's agents)
- **Complete Documentation**: Should not duplicate full reference material
- **Implementation Guides**: Should provide patterns, not tutorials

## The Skill Contract

```
INPUT: Agent needs specific information to complete task
       ↓
SKILL RESPONSIBILITIES:
1. Provide immediately actionable patterns
2. Show common use cases with examples
3. Highlight critical gotchas
4. Reference full docs for advanced cases
       ↓
OUTPUT: Agent has what it needs OR knows where to look
```

## Structure Standards

### Required SKILL.md Structure
```markdown
---
name: skill-name
description: What this skill provides. Use for [specific use case].
---

# Skill Name

## Quick Patterns
[Most common 3-5 patterns with code]

## Critical Gotchas
[Things that WILL break if ignored]

## Common Mistakes
1. ❌ [Wrong way]
   ✅ [Correct way]

## Examples
[Working, tested examples]

## Full Documentation
See `sdk-users/path/to/CLAUDE.md` for complete reference.
```

### Content Hierarchy
```
Skill Content (by frequency of use):
├── Quick Patterns:      40%  ← Most used, instant access
├── Critical Gotchas:    20%  ← Must-know warnings
├── Common Mistakes:     15%  ← Error prevention
├── Examples:            15%  ← Working demonstrations
└── Doc References:      10%  ← Pointers to full docs
```

## Quality Criteria

### Length Guidelines
| Quality | Lines | Symptoms |
|---------|-------|----------|
| Too Short (<30) | Missing patterns | Skill not useful |
| Optimal (50-250) | Focused, actionable | Quick task completion |
| Too Long (>300) | Documentation duplication | Context waste |

### Content Density
```
Optimal Skill:
- 80% actionable content (patterns, examples, gotchas)
- 20% reference content (doc pointers, explanations)

Red Flag:
- 50%+ explanatory text = should be in full docs
- 50%+ code examples = consider splitting into sub-skills
```

## Quality Checklist

### Structural Quality
- [ ] SKILL.md exists with frontmatter
- [ ] Description clearly states use case
- [ ] Quick Patterns section present
- [ ] Examples are tested and working
- [ ] Full Documentation section points to sdk-users

### Content Quality
- [ ] Patterns are copy-paste ready
- [ ] Gotchas highlight real failure modes
- [ ] Common Mistakes show before/after
- [ ] No duplicated content from other skills
- [ ] No content that belongs in full docs

### Anti-Patterns Avoided
- [ ] No tutorial-style explanations
- [ ] No policy/process guidance (belongs in agents)
- [ ] No duplicated patterns across skills
- [ ] No untested example code

## Quality Issues in Current Kailash Setup

### Review Score: 7.8/10

**Strengths:**
- Comprehensive coverage of Kailash SDK
- Good cross-references to sdk-users
- Structured with consistent naming

**Issues Found:**

#### 1. Pattern Duplication (CRITICAL)
The 4-param pattern appears in 5+ locations:
- `01-core-sdk/SKILL.md`
- `02-dataflow/SKILL.md`
- `08-nodes-reference/SKILL.md`
- `14-code-templates/SKILL.md`
- `17-gold-standards/SKILL.md`

**Fix**: Single source in `01-core-sdk`, references elsewhere:
```markdown
## Node Configuration
For the 4-param pattern, see `/01-core-sdk` Quick Patterns section.
```

#### 2. DataFlow SKILL.md Bloat
Current: 570 lines
Target: 250 lines (56% reduction needed)

**Content Analysis:**
```
Current DataFlow SKILL.md:
├── Installation/Setup:     80 lines (move to sdk-users)
├── Model Definition:      100 lines (keep patterns, move details)
├── Node Operations:       150 lines (keep)
├── Migration Guide:       120 lines (move to sdk-users)
├── Examples:              120 lines (keep best 3, move rest)
```

**Fix**: Extract to sdk-users, keep only:
- Quick model pattern (20 lines)
- Node operation patterns (100 lines)
- Critical gotchas (50 lines)
- Top 3 examples (60 lines)
- Doc references (20 lines)

#### 3. Missing Cross-Skill Links
Skills don't reference related skills.

```markdown
# ADD to each skill:
## Related Skills
- `/01-core-sdk` - Core workflow patterns
- `/17-gold-standards` - Compliance requirements
```

#### 4. Inconsistent Gotcha Format
Some skills use prose, others use lists.

**Standardize:**
```markdown
## Critical Gotchas

1. **Primary Key Must Be `id`**
   DataFlow requires primary key named exactly `id`.
   ❌ `user_id: int = Field(primary_key=True)`
   ✅ `id: int = Field(primary_key=True)`

2. **Auto-Managed Timestamps**
   NEVER set `created_at`/`updated_at` manually.
   ❌ `{"created_at": datetime.now()}`
   ✅ `{}` (auto-populated)
```

## Skill Categories and Structure

### Framework Skills (02-dataflow, 03-nexus, 04-kaizen, 05-mcp)
```markdown
## Quick Patterns
[Framework-specific patterns]

## Node Reference
[Key nodes with signatures]

## Integration Points
[How framework connects to others]

## Critical Gotchas
[Framework-specific warnings]

## Full Documentation
sdk-users/apps/[framework]/CLAUDE.md
```

### Reference Skills (08-nodes-reference, 14-code-templates)
```markdown
## Index
[Categorized list of available items]

## Quick Access
[Most commonly used 10-15 items]

## Full Catalog
See sdk-users for complete listings.
```

### Strategy Skills (12-testing, 13-architecture)
```markdown
## Decision Framework
[When to use what]

## Quick Comparison
[Table of options]

## Patterns Per Strategy
[Implementation patterns]

## Full Documentation
sdk-users/path/to/CLAUDE.md
```

## Template: Framework Skill

```markdown
---
name: [framework]-skill
description: Quick patterns for [Framework]. Use for [specific operations].
---

# [Framework] Quick Reference

## Installation
```bash
pip install kailash-[framework]
```

## Quick Patterns

### Pattern 1: [Most Common Operation]
```python
[Copy-paste ready code]
```

### Pattern 2: [Second Most Common]
```python
[Copy-paste ready code]
```

### Pattern 3: [Third Most Common]
```python
[Copy-paste ready code]
```

## Critical Gotchas

1. **[Issue Name]**
   [Brief explanation]
   ❌ `[Wrong code]`
   ✅ `[Correct code]`

2. **[Issue Name]**
   [Brief explanation]
   ❌ `[Wrong code]`
   ✅ `[Correct code]`

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| [Wrong] | [Right] |
| [Wrong] | [Right] |

## Examples

### [Use Case 1]
```python
[Complete working example]
```

### [Use Case 2]
```python
[Complete working example]
```

## Related Skills
- `/01-core-sdk` - Core patterns
- `/17-gold-standards` - Compliance

## Full Documentation
For complete reference:
- `sdk-users/apps/[framework]/CLAUDE.md`
```

## Improvement Actions

### Immediate
1. Deduplicate 4-param pattern (keep in 01-core-sdk only)
2. Add Related Skills section to all skills
3. Standardize gotcha format

### Short-term
1. Reduce DataFlow SKILL.md from 570 to 250 lines
2. Move tutorial content to sdk-users
3. Add tested example validation

### Long-term
1. Create skill coverage metrics
2. Implement duplication detection
3. Add automatic line count warnings
