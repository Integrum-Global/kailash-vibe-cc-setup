# Directory Structure for Hooks Infrastructure

## Required Directories

```bash
# Create hooks directory
mkdir -p scripts/hooks

# Verify .claude directory exists
ls -la .claude/

# Expected structure after implementation:
kailash-vibe-cc-setup/
├── .claude/
│   ├── settings.json          # NEW - Hook configuration
│   ├── settings.local.json    # EXISTS - Permissions (DO NOT MODIFY)
│   ├── agents/                # EXISTS
│   ├── skills/                # EXISTS
│   ├── guides/                # EXISTS
│   └── rules/                 # NEW - Create in Phase 2
│
└── scripts/
    └── hooks/                 # NEW
        ├── validate-bash-command.js
        ├── validate-workflow.js
        ├── auto-format.js
        ├── session-start.js
        ├── session-end.js
        └── pre-compact.js
```

## Step-by-Step Creation

### Step 1: Create Scripts Directory
```bash
mkdir -p ./scripts/hooks
```

### Step 2: Verify Existing .claude Structure
```bash
ls -la ./.claude/
# Should show:
# settings.local.json (EXISTS - permissions)
# agents/ (EXISTS)
# skills/ (EXISTS)
# guides/ (EXISTS)
```

### Step 3: Create Session Storage Directory
This is created at runtime by hooks, but can be pre-created:
```bash
mkdir -p ~/.claude/sessions
mkdir -p ~/.claude/checkpoints
```

## File Ownership and Permissions

All hook scripts must be executable:
```bash
chmod +x scripts/hooks/*.js
```

## CRITICAL: settings.json vs settings.local.json

| File | Purpose | Action |
|------|---------|--------|
| `settings.json` | Hooks configuration, shared settings | CREATE NEW |
| `settings.local.json` | Permissions, local overrides | DO NOT MODIFY |

**Why separate files?**
- `settings.local.json` contains user-specific permissions
- `settings.json` contains project-wide hooks
- Hooks should be version controlled; permissions should not

## Verification Checklist

```bash
# After creating structure:
[_] scripts/hooks/ directory exists
[_] All .js files are executable (chmod +x)
[_] ~/.claude/sessions/ exists
[_] ~/.claude/checkpoints/ exists
[_] .claude/settings.json will be created (not yet)
[_] .claude/settings.local.json is UNTOUCHED
```
