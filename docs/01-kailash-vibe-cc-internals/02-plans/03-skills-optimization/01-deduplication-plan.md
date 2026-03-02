# Skill Deduplication Plan

## The Problem

The 4-param pattern (workflow.add_node signature) appears in 5+ skill files:

```python
# This pattern is duplicated everywhere:
workflow.add_node("NodeName", "node_id", {
    "param1": "value1",
    "param2": "value2"
})
```

**Why it's a problem**:
- If signature changes, 5+ files need updating
- Inconsistent examples across files
- Context waste loading same info multiple times
- Maintenance burden

## The Solution

**Single Source**: Keep ONLY in `01-core-sdk/SKILL.md`
**All Others**: Reference `01-core-sdk` instead of duplicating

## Current Duplication Map

| File | Pattern Location | Lines | Action |
|------|------------------|-------|--------|
| `01-core-sdk/` | Core patterns section | ~30 | KEEP (canonical) |
| `02-dataflow/` | Node usage section | ~25 | REMOVE, add reference |
| `08-nodes-reference/` | Node signatures | ~40 | REMOVE, add reference |
| `14-code-templates/` | Template examples | ~20 | REMOVE, add reference |
| `17-gold-standards/` | Required patterns | ~15 | REMOVE, add reference |

## Implementation Steps

### Step 1: Identify Canonical Version

The `01-core-sdk/` version becomes canonical. It should include:

```markdown
## Node Configuration Pattern (Canonical)

All Kailash SDK nodes use this 4-parameter pattern:

\`\`\`python
workflow.add_node(
    "NodeClassName",  # 1. Node type (PascalCase)
    "unique_node_id", # 2. Unique ID (snake_case)
    {                 # 3. Configuration dict
        "param1": "value",
        "param2": 123
    },
    connections=[]    # 4. Optional: input connections
)
\`\`\`

### Parameters Explained

| Parameter | Type | Description |
|-----------|------|-------------|
| Node type | str | The node class name |
| Node ID | str | Unique identifier for this instance |
| Config | dict | Node-specific configuration |
| Connections | list | Optional input connections |

### Common Node Types

- Data: `ReadFile`, `WriteFile`, `DataTransform`
- API: `HTTPRequest`, `APIClient`
- Logic: `Condition`, `Loop`, `Switch`
- AI: `LLMNode`, `EmbeddingNode`

For full node reference, see `/08-nodes-reference`.
```

### Step 2: Remove Duplicates

For each duplicate location, replace with:

```markdown
## Node Configuration

For the 4-param node pattern, see `/01-core-sdk` Quick Patterns section.

### [Specific to this skill]
[Only include what's UNIQUE to this skill]
```

### Step 3: Update 02-dataflow

**Before** (duplicated):
```markdown
## Creating DataFlow Nodes

DataFlow uses the standard 4-param pattern:
\`\`\`python
workflow.add_node("User_CREATE", "create_user", {...})
\`\`\`
[... 25 more lines explaining the pattern ...]
```

**After** (reference):
```markdown
## DataFlow Node Operations

DataFlow nodes follow the standard 4-param pattern. See `/01-core-sdk` for details.

### DataFlow-Specific Nodes

DataFlow generates these nodes per model:
- `{Model}_CREATE` - Create record
- `{Model}_READ` - Read by ID
- `{Model}_UPDATE` - Update record
- `{Model}_DELETE` - Delete record
- `{Model}_LIST` - List with filters
- `{Model}_UPSERT` - Create or update
- `{Model}_COUNT` - Count records
- `{Model}_BULK_CREATE` - Bulk create
- `{Model}_BULK_UPDATE` - Bulk update
- `{Model}_BULK_DELETE` - Bulk delete
- `{Model}_BULK_UPSERT` - Bulk upsert

### Example: User CRUD

\`\`\`python
# Only show DataFlow-specific usage
workflow.add_node("User_CREATE", "create", {
    "name": "John",  # Model fields, not generic params
    "email": "john@example.com"
})
\`\`\`
```

### Step 4: Update 08-nodes-reference

**Before** (duplicated):
```markdown
## Node Signatures

All nodes use this signature:
\`\`\`python
workflow.add_node("NodeType", "id", config, connections)
\`\`\`
[... repeated explanation ...]
```

**After** (reference):
```markdown
## Node Signatures

All nodes follow the 4-param pattern from `/01-core-sdk`.

This reference documents node-specific configurations only.

### AI Nodes

#### LLMNode
Config: `{"model": str, "prompt": str, "temperature": float}`

#### EmbeddingNode
Config: `{"model": str, "input": str}`

[... node-specific configs only ...]
```

### Step 5: Update 14-code-templates

**Before** (duplicated):
```markdown
## Template: Basic Workflow

\`\`\`python
workflow = WorkflowBuilder()
workflow.add_node("NodeType", "id", {"param": "value"})
# ... pattern explanation ...
\`\`\`
```

**After** (reference):
```markdown
## Template: Basic Workflow

Uses the 4-param pattern from `/01-core-sdk`.

\`\`\`python
from kailash.workflow.builder import WorkflowBuilder
from kailash.runtime import LocalRuntime

# Create workflow
workflow = WorkflowBuilder()

# Add nodes (see /01-core-sdk for pattern details)
workflow.add_node("ReadFile", "read", {"path": "input.txt"})
workflow.add_node("Transform", "transform", {"operation": "uppercase"})
workflow.add_node("WriteFile", "write", {"path": "output.txt"})

# Connect nodes
workflow.connect("read", "transform")
workflow.connect("transform", "write")

# Execute
runtime = LocalRuntime()
results, run_id = runtime.execute(workflow.build())
\`\`\`

Focus: Complete working example, not pattern explanation.
```

### Step 6: Update 17-gold-standards

**Before** (duplicated):
```markdown
## Mandatory Patterns

### Node Pattern
\`\`\`python
workflow.add_node("Type", "id", {...})
\`\`\`
Must always use this format.
```

**After** (reference):
```markdown
## Mandatory Patterns

### Node Pattern
**Requirement**: Always use the 4-param pattern from `/01-core-sdk`.

**Validation**: Gold-standards-validator checks for:
- String-based node IDs (not variables)
- PascalCase node types
- Dict config (not kwargs)

See `/01-core-sdk` for correct usage.
```

## Verification

After deduplication:

```bash
# Search for duplicate pattern across skills
grep -r "workflow.add_node" .claude/skills/ --include="*.md" | wc -l
# Should be significantly reduced

# Verify 01-core-sdk has canonical version
grep -A 20 "4-param" .claude/skills/01-core-sdk/SKILL.md

# Verify others reference it
grep "See.*01-core-sdk" .claude/skills/02-dataflow/SKILL.md
grep "See.*01-core-sdk" .claude/skills/08-nodes-reference/SKILL.md
```

## Expected Line Reduction

| Skill | Before | After | Saved |
|-------|--------|-------|-------|
| 02-dataflow | 570 | ~545 | 25 |
| 08-nodes-reference | Unknown | -40 | 40 |
| 14-code-templates | Unknown | -20 | 20 |
| 17-gold-standards | Unknown | -15 | 15 |
| **Total** | | | ~100 lines |
