# Hook Philosophy and Quality Guide

## First Principles

### What Hooks ARE
- **Deterministic Automators**: Execute predictable logic without LLM judgment
- **Guardrails**: Prevent dangerous operations before execution
- **Formatters**: Apply consistent transformations after operations
- **Session Managers**: Maintain state across interactions

### What Hooks are NOT
- **Decision Makers**: Should not require LLM-level judgment
- **Complex Processors**: Should be fast and simple
- **User Interaction Points**: Should work silently

## The Hook Contract

```
INPUT: Tool invocation or session event
       ↓
HOOK RESPONSIBILITIES:
1. Validate input (PreToolUse)
2. Transform output (PostToolUse)
3. Initialize state (SessionStart)
4. Persist state (SessionEnd)
5. Prepare compaction (PreCompact)
       ↓
OUTPUT: Continue, block, or modify
```

## Hook Event Types

### 1. PreToolUse
**Trigger**: Before a tool executes
**Use Cases**:
- Block dangerous commands
- Validate inputs
- Add warnings
- Suggest alternatives

```json
{
  "matcher": "Bash|Edit|Write",
  "hooks": [{
    "type": "command",
    "command": "scripts/hooks/pre-tool.js",
    "timeout": 10
  }]
}
```

### 2. PostToolUse
**Trigger**: After a tool completes
**Use Cases**:
- Format code
- Run linters
- Type check
- Collect metrics

```json
{
  "matcher": "Edit|Write",
  "hooks": [{
    "type": "command",
    "command": "scripts/hooks/auto-format.js",
    "timeout": 30
  }]
}
```

### 3. SessionStart
**Trigger**: When Claude Code session begins
**Use Cases**:
- Load previous state
- Initialize logging
- Set environment
- Display reminders

### 4. SessionEnd
**Trigger**: When session closes
**Use Cases**:
- Persist state
- Flush logs
- Clean up resources
- Record metrics

### 5. PreCompact
**Trigger**: Before context compaction
**Use Cases**:
- Save important context
- Mark critical information
- Archive decisions

### 6. Stop
**Trigger**: When stop signal received
**Use Cases**:
- Emergency cleanup
- State preservation
- Graceful shutdown

## Structure Standards

### Hook Configuration (settings.json)
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "ToolName|AnotherTool",
        "hooks": [{
          "type": "command",
          "command": "path/to/script.js",
          "timeout": 10
        }]
      }
    ],
    "PostToolUse": [...],
    "SessionStart": [{ "hooks": [...] }],
    "SessionEnd": [{ "hooks": [...] }]
  }
}
```

### Hook Script Template (Node.js)
```javascript
#!/usr/bin/env node
const fs = require('fs');

// Read input from stdin (JSON)
let input = '';
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  const data = JSON.parse(input);

  // data contains:
  // - session_id: string
  // - tool_name: string (for tool hooks)
  // - tool_input: object (for tool hooks)
  // - cwd: string

  // Perform validation/transformation
  const result = processHook(data);

  // Output result
  console.log(JSON.stringify({
    continue: result.continue,
    hookSpecificOutput: {
      message: result.message
    }
  }));

  // Exit codes:
  // 0 = success (continue)
  // 2 = blocking error (stop tool)
  // other = warning (continue with message)
  process.exit(result.exitCode);
});

function processHook(data) {
  // Implementation here
  return { continue: true, message: '', exitCode: 0 };
}
```

## Quality Criteria

### Execution Time Limits
| Hook Type | Max Timeout | Ideal Time |
|-----------|-------------|------------|
| PreToolUse | 10s | <1s |
| PostToolUse | 30s | <5s |
| SessionStart | 5s | <2s |
| SessionEnd | 10s | <3s |
| PreCompact | 5s | <2s |

### Decision Complexity
```
APPROPRIATE for hooks:
├── Pattern matching (regex)
├── File existence checks
├── Environment variable lookup
├── Simple conditional logic
└── External tool invocation

NOT APPROPRIATE for hooks:
├── Natural language understanding
├── Complex code analysis
├── Multi-step reasoning
├── User intent interpretation
└── Contextual decision making
```

## Quality Checklist

### Configuration Quality
- [ ] Matchers use minimal regex (specific tools only)
- [ ] Timeouts appropriate for hook complexity
- [ ] Script paths are valid
- [ ] Cross-platform compatibility (Node.js preferred)

### Script Quality
- [ ] Handles JSON input/output correctly
- [ ] Uses appropriate exit codes
- [ ] Fails gracefully (non-blocking on error)
- [ ] Includes error messages for debugging
- [ ] No external dependencies beyond Node.js stdlib

### Anti-Patterns Avoided
- [ ] No LLM-like decision making
- [ ] No long-running operations
- [ ] No user prompts/interactions
- [ ] No side effects on blocking failure
- [ ] No hardcoded paths (use cwd/env)

## Recommended Hook Suite for Kailash

### 1. PreToolUse: Bash Command Validation
```javascript
// scripts/hooks/validate-bash.js
// Block: rm -rf /, sudo without confirmation, secrets in commands
// Warn: Long-running commands without tmux
// Allow: All other commands
```

### 2. PreToolUse: Dangerous File Detection
```javascript
// scripts/hooks/validate-write.js
// Block: Writing to .env with secrets visible
// Warn: Overwriting existing files
// Allow: Normal file operations
```

### 3. PostToolUse: Auto-Format
```javascript
// scripts/hooks/auto-format.js
// Python files: black + isort
// JS/TS files: prettier
// JSON files: prettier
// Ignore: Other files
```

### 4. PostToolUse: Type Check
```javascript
// scripts/hooks/type-check.js
// Python files: mypy (if configured)
// TypeScript files: tsc --noEmit
// Report: Errors as warnings
```

### 5. SessionStart: State Load
```javascript
// scripts/hooks/session-start.js
// Load: Previous session state from ~/.claude/sessions/
// Set: Environment variables from .env
// Display: Pending todos from previous session
```

### 6. SessionEnd: State Save
```javascript
// scripts/hooks/session-end.js
// Save: Current todos
// Save: Session summary
// Log: Session metrics
```

## Hook Testing Procedures

### Test PreToolUse Hooks
```bash
# 1. Create test hook that logs
echo '#!/usr/bin/env node
console.error("PreToolUse fired");
console.log(JSON.stringify({continue: true}));
' > /tmp/test-hook.js
chmod +x /tmp/test-hook.js

# 2. Configure in settings.json
# 3. Run Claude with --verbose
# 4. Trigger tool, check stderr for "PreToolUse fired"
```

### Test PostToolUse Hooks
```bash
# 1. Create Python file with bad formatting
echo "def foo():  return    1" > /tmp/test.py

# 2. In Claude, edit the file
# 3. Verify formatting was applied
cat /tmp/test.py
```

### Test Session Hooks
```bash
# 1. Start session
claude --verbose

# 2. Do work, note session ID

# 3. Exit and check state file
ls ~/.claude/sessions/

# 4. Resume session
claude --resume last
```

## Kailash-Specific Recommendations

### Priority Hook Implementations

1. **Environment Variable Validation (CRITICAL)**
   - Check .env exists before pytest/scripts
   - Verify required API keys present
   - Block execution if missing

2. **Import Pattern Validation**
   - Check for relative imports in kailash code
   - Warn if not using absolute imports

3. **Runtime Pattern Validation**
   - Detect `workflow.execute(runtime)` anti-pattern
   - Suggest `runtime.execute(workflow.build())`

4. **Test Mock Detection**
   - Warn if mocking in Tier 2/3 tests
   - Enforce NO MOCKING policy

## Current Gap Analysis

**Kailash Setup**: 0 hooks configured

**Impact**:
- No automatic formatting
- No dangerous command prevention
- No session state persistence
- No continuous learning observation

**Recommendation**: Implement all 6 recommended hooks as Priority 1 item.
