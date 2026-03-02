# Testing and Validation

## Pre-Implementation Checklist

Before testing hooks, ensure:

```bash
[_] scripts/hooks/ directory exists
[_] All .js files created
[_] All .js files executable (chmod +x)
[_] .claude/settings.json created
[_] settings.json JSON syntax is valid
```

## Test Each Hook Individually

### Test 1: validate-bash-command.js

```bash
# Test 1a: Valid command (should pass)
echo '{"tool_input":{"command":"ls -la"}}' | node scripts/hooks/validate-bash-command.js
# Expected: {"continue":true,...}

# Test 1b: Dangerous command (should block)
echo '{"tool_input":{"command":"rm -rf /"}}' | node scripts/hooks/validate-bash-command.js
# Expected: {"continue":false,...}, exit code 2

# Test 1c: Git push warning
echo '{"tool_input":{"command":"git push origin main"}}' | node scripts/hooks/validate-bash-command.js
# Expected: {"continue":true,...} with warning about security review
```

### Test 2: validate-workflow.js

```bash
# Create test file with anti-pattern
cat > /tmp/test_workflow.py << 'EOF'
from kailash.workflow.builder import WorkflowBuilder
from kailash.runtime import LocalRuntime

workflow = WorkflowBuilder()
runtime = LocalRuntime()
# Anti-pattern below:
workflow.execute(runtime)
EOF

# Test (should warn)
echo '{"tool_input":{"file_path":"/tmp/test_workflow.py"}}' | node scripts/hooks/validate-workflow.js
# Expected: Warning about workflow.execute(runtime) anti-pattern
```

### Test 3: auto-format.js

```bash
# Create test file with bad formatting
echo "def foo():  return    1" > /tmp/test.py

# Test (should format)
echo '{"tool_input":{"file_path":"/tmp/test.py"}}' | node scripts/hooks/auto-format.js
# Expected: {"continue":true,"hookSpecificOutput":{"formatted":true,"formatter":"black"}}

# Verify formatting
cat /tmp/test.py
# Expected: def foo():\n    return 1
```

### Test 4: session-start.js

```bash
# Test
echo '{"session_id":"test-123","cwd":"/tmp"}' | node scripts/hooks/session-start.js
# Expected: {"continue":true,...,"envExists":false}

# Verify session directory created
ls ~/.claude/sessions/
```

### Test 5: session-end.js

```bash
# Test
echo '{"session_id":"test-123","cwd":"/tmp"}' | node scripts/hooks/session-end.js
# Expected: {"continue":true,...,"saved":true}

# Verify session file created
cat ~/.claude/sessions/test-123.json
```

### Test 6: pre-compact.js

```bash
# Test
echo '{"session_id":"test-123","cwd":"/tmp"}' | node scripts/hooks/pre-compact.js
# Expected: {"continue":true,...,"checkpointed":true}

# Verify checkpoint created
ls ~/.claude/checkpoints/
```

## Integration Test

### Full Session Test

```bash
# 1. Start Claude with verbose logging
claude --verbose

# 2. In session, run a bash command
# > "Run ls -la"
# Expected: See "PreToolUse hook triggered for Bash" in verbose output

# 3. Edit a Python file
# > "Create a simple Python function in /tmp/hello.py"
# Expected: See "PostToolUse hook triggered for Write" in verbose output
# Expected: File should be auto-formatted

# 4. Check session state
# > exit
# Expected: See "SessionEnd hook triggered" in verbose output

# 5. Verify state saved
cat ~/.claude/sessions/last-session.json
```

## Validation Checklist

### Hook Execution Verification

```bash
# Run each verification:
[_] PreToolUse fires on Bash command
[_] PostToolUse fires on Edit
[_] PostToolUse fires on Write
[_] SessionStart fires on session begin
[_] SessionEnd fires on session end
[_] PreCompact fires before compaction
```

### Exit Code Verification

```bash
# For each hook script:
[_] Returns 0 on success
[_] Returns 2 on blocking error (only for PreToolUse)
[_] Returns 1 on non-blocking error
[_] Never hangs or times out
```

### State Persistence Verification

```bash
# After session:
[_] ~/.claude/sessions/ contains session files
[_] ~/.claude/sessions/last-session.json exists
[_] ~/.claude/checkpoints/ contains checkpoint files (if compacted)
[_] ~/.claude/kailash-learning/observations.jsonl contains entries
```

### Formatting Verification

```bash
# Create badly formatted test files:
echo "def foo():  return    1" > /tmp/test.py
echo "const x={a:1,b:2}" > /tmp/test.js

# Edit them in Claude session, then verify:
[_] Python files formatted by black
[_] JavaScript files formatted by prettier
[_] TypeScript files formatted by prettier
```

## Troubleshooting

### Problem: Hook not firing

**Symptoms**: No hook output in verbose mode

**Solutions**:
1. Check `settings.json` syntax: `node -e "JSON.parse(require('fs').readFileSync('.claude/settings.json'))"`
2. Check matcher pattern matches tool name exactly
3. Check script path is relative to project root
4. Check script is executable: `ls -la scripts/hooks/`

### Problem: Hook blocking unexpectedly

**Symptoms**: Tool execution blocked when it shouldn't be

**Solutions**:
1. Check script exit code: `echo '{"tool_input":{}}' | node scripts/hooks/[name].js; echo $?`
2. Check JSON output has `"continue": true`
3. Check stderr for error messages

### Problem: Hook timing out

**Symptoms**: "Hook timed out" error

**Solutions**:
1. Increase timeout in settings.json
2. Profile script: `time echo '{}' | node scripts/hooks/[name].js`
3. Remove slow operations (network calls, large file reads)

### Problem: Session state not persisting

**Symptoms**: State not available on resume

**Solutions**:
1. Check directory permissions: `ls -la ~/.claude/`
2. Check session-end hook runs: look for "SessionEnd" in verbose output
3. Manually check file: `cat ~/.claude/sessions/last-session.json`

## Success Criteria Summary

The hooks infrastructure is successfully implemented when:

| Criterion | Test Method | Expected |
|-----------|-------------|----------|
| All hooks fire | Run with `--verbose` | See hook logs |
| Dangerous commands blocked | Try `rm -rf /` | Blocked with message |
| Files auto-formatted | Edit .py file | Formatted by black |
| Session persists | Exit and check | State file exists |
| State loads on resume | Resume session | Previous state loaded |
| Observations logged | Check file | Entries in observations.jsonl |
