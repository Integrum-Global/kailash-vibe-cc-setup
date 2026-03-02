# Hook Script Implementations

## Hook Script Template

All hooks follow this pattern:

```javascript
#!/usr/bin/env node
/**
 * Hook: [Name]
 * Event: [PreToolUse|PostToolUse|SessionStart|SessionEnd|PreCompact]
 * Purpose: [Description]
 *
 * Exit Codes:
 *   0 = success (continue)
 *   2 = blocking error (stop tool execution)
 *   other = non-blocking error (warn and continue)
 */

const fs = require('fs');
const path = require('path');

// Read JSON from stdin
let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const result = processHook(data);
    outputResult(result);
  } catch (error) {
    handleError(error);
  }
});

function processHook(data) {
  // Implementation here
  return { continue: true, exitCode: 0 };
}

function outputResult(result) {
  console.log(JSON.stringify({
    continue: result.continue,
    hookSpecificOutput: {
      hookEventName: process.env.HOOK_EVENT_NAME,
      ...result.output
    }
  }));
  process.exit(result.exitCode);
}

function handleError(error) {
  console.error(`[HOOK ERROR] ${error.message}`);
  console.log(JSON.stringify({ continue: true }));
  process.exit(1); // Non-blocking error
}
```

---

## Hook 1: validate-bash-command.js

**Purpose**: Block dangerous bash commands, suggest alternatives

```javascript
#!/usr/bin/env node
/**
 * Hook: validate-bash-command
 * Event: PreToolUse
 * Matcher: Bash
 * Purpose: Block dangerous commands, suggest tmux for long-running
 */

const fs = require('fs');

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const result = validateBashCommand(data);
    console.log(JSON.stringify({
      continue: result.continue,
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        validation: result.message
      }
    }));
    process.exit(result.exitCode);
  } catch (error) {
    console.error(`[HOOK ERROR] ${error.message}`);
    console.log(JSON.stringify({ continue: true }));
    process.exit(1);
  }
});

function validateBashCommand(data) {
  const command = data.tool_input?.command || '';

  // BLOCK: Dangerous commands
  const dangerousPatterns = [
    { pattern: /rm\s+-rf\s+\/(?!\w)/, message: 'Blocked: rm -rf / (system destruction)' },
    { pattern: />\s*\/dev\/sd/, message: 'Blocked: Writing to block device' },
    { pattern: /mkfs\./, message: 'Blocked: Filesystem formatting' },
    { pattern: /dd\s+if=.*of=\/dev\/sd/, message: 'Blocked: dd to disk' },
    { pattern: /:\(\)\{\s*:\|:&\s*\};:/, message: 'Blocked: Fork bomb' },
  ];

  for (const { pattern, message } of dangerousPatterns) {
    if (pattern.test(command)) {
      return { continue: false, exitCode: 2, message };
    }
  }

  // WARN: Long-running commands outside tmux
  const longRunningPatterns = [
    /npm\s+run\s+(dev|start|serve)/,
    /yarn\s+(dev|start|serve)/,
    /python\s+-m\s+http\.server/,
    /uvicorn/,
    /flask\s+run/,
    /node\s+.*server/,
  ];

  const inTmux = process.env.TMUX || process.env.TERM_PROGRAM === 'tmux';

  for (const pattern of longRunningPatterns) {
    if (pattern.test(command) && !inTmux) {
      return {
        continue: true,
        exitCode: 0,
        message: 'WARNING: Long-running command outside tmux. Consider: tmux new-session -d "' + command + '"'
      };
    }
  }

  // WARN: Git push without review
  if (/git\s+push/.test(command)) {
    return {
      continue: true,
      exitCode: 0,
      message: 'REMINDER: Did you run security-reviewer before pushing?'
    };
  }

  return { continue: true, exitCode: 0, message: 'Validated' };
}
```

---

## Hook 2: validate-workflow.js

**Purpose**: Enforce Kailash SDK patterns

```javascript
#!/usr/bin/env node
/**
 * Hook: validate-workflow
 * Event: PostToolUse
 * Matcher: Edit|Write
 * Purpose: Enforce Kailash SDK patterns in Python files
 */

const fs = require('fs');
const path = require('path');

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const result = validateWorkflowPatterns(data);
    console.log(JSON.stringify({
      continue: result.continue,
      hookSpecificOutput: {
        hookEventName: 'PostToolUse',
        validation: result.messages
      }
    }));
    process.exit(result.exitCode);
  } catch (error) {
    console.error(`[HOOK ERROR] ${error.message}`);
    console.log(JSON.stringify({ continue: true }));
    process.exit(1);
  }
});

function validateWorkflowPatterns(data) {
  const filePath = data.tool_input?.file_path || '';
  const messages = [];

  // Only check Python files
  if (!filePath.endsWith('.py')) {
    return { continue: true, exitCode: 0, messages: ['Not a Python file'] };
  }

  let content;
  try {
    content = fs.readFileSync(filePath, 'utf8');
  } catch (e) {
    return { continue: true, exitCode: 0, messages: ['Could not read file'] };
  }

  // Check 1: Anti-pattern workflow.execute(runtime)
  if (/workflow\s*\.\s*execute\s*\(\s*runtime/.test(content)) {
    messages.push('WARNING: Found workflow.execute(runtime). Use runtime.execute(workflow.build()) instead.');
  }

  // Check 2: Missing .build() call
  if (/runtime\s*\.\s*execute\s*\(\s*workflow\s*[^.]/.test(content)) {
    messages.push('WARNING: Missing .build() call. Use runtime.execute(workflow.build())');
  }

  // Check 3: Relative imports in kailash code
  if (/from\s+['"]\./.test(content) && /kailash/.test(filePath)) {
    messages.push('WARNING: Relative imports detected. Use absolute imports for Kailash code.');
  }

  // Check 4: Mocking in test files (Tier 2-3 detection)
  if (/_test\.py$|test_.*\.py$/.test(filePath)) {
    const mockPatterns = [
      { pattern: /@patch\(/, name: '@patch decorator' },
      { pattern: /MagicMock/, name: 'MagicMock' },
      { pattern: /unittest\.mock/, name: 'unittest.mock' },
      { pattern: /from\s+mock\s+import/, name: 'mock import' },
    ];

    for (const { pattern, name } of mockPatterns) {
      if (pattern.test(content)) {
        messages.push(`WARNING: ${name} detected. Remember: NO MOCKING in Tier 2-3 tests.`);
      }
    }
  }

  return {
    continue: true, // Always continue, just warn
    exitCode: 0,
    messages: messages.length > 0 ? messages : ['All Kailash patterns validated']
  };
}
```

---

## Hook 3: auto-format.js

**Purpose**: Auto-format files after edit/write

```javascript
#!/usr/bin/env node
/**
 * Hook: auto-format
 * Event: PostToolUse
 * Matcher: Edit|Write
 * Purpose: Auto-format Python, JavaScript, TypeScript files
 */

const fs = require('fs');
const { execSync } = require('child_process');
const path = require('path');

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const result = autoFormat(data);
    console.log(JSON.stringify({
      continue: true,
      hookSpecificOutput: {
        hookEventName: 'PostToolUse',
        formatted: result.formatted,
        formatter: result.formatter
      }
    }));
    process.exit(0);
  } catch (error) {
    console.error(`[HOOK ERROR] ${error.message}`);
    console.log(JSON.stringify({ continue: true }));
    process.exit(1);
  }
});

function autoFormat(data) {
  const filePath = data.tool_input?.file_path;

  if (!filePath || !fs.existsSync(filePath)) {
    return { formatted: false, formatter: 'none' };
  }

  const ext = path.extname(filePath).toLowerCase();

  try {
    // Python files: black
    if (ext === '.py') {
      try {
        execSync(`black "${filePath}" 2>/dev/null`, { stdio: 'pipe' });
        return { formatted: true, formatter: 'black' };
      } catch {
        // Try ruff if black not available
        try {
          execSync(`ruff format "${filePath}" 2>/dev/null`, { stdio: 'pipe' });
          return { formatted: true, formatter: 'ruff' };
        } catch {
          return { formatted: false, formatter: 'none (black/ruff not found)' };
        }
      }
    }

    // JavaScript/TypeScript files: prettier
    if (['.js', '.jsx', '.ts', '.tsx', '.json'].includes(ext)) {
      try {
        execSync(`npx prettier --write "${filePath}" 2>/dev/null`, { stdio: 'pipe' });
        return { formatted: true, formatter: 'prettier' };
      } catch {
        return { formatted: false, formatter: 'none (prettier not found)' };
      }
    }

    // YAML/Markdown: prettier
    if (['.yaml', '.yml', '.md'].includes(ext)) {
      try {
        execSync(`npx prettier --write "${filePath}" 2>/dev/null`, { stdio: 'pipe' });
        return { formatted: true, formatter: 'prettier' };
      } catch {
        return { formatted: false, formatter: 'none' };
      }
    }

    return { formatted: false, formatter: 'unsupported file type' };
  } catch (error) {
    return { formatted: false, formatter: `error: ${error.message}` };
  }
}
```

---

## Hook 4: session-start.js

**Purpose**: Load previous session state

```javascript
#!/usr/bin/env node
/**
 * Hook: session-start
 * Event: SessionStart
 * Purpose: Load previous session state, initialize logging
 */

const fs = require('fs');
const path = require('path');

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const result = initializeSession(data);
    console.log(JSON.stringify({
      continue: true,
      hookSpecificOutput: {
        hookEventName: 'SessionStart',
        ...result
      }
    }));
    process.exit(0);
  } catch (error) {
    console.error(`[HOOK ERROR] ${error.message}`);
    console.log(JSON.stringify({ continue: true }));
    process.exit(1);
  }
});

function initializeSession(data) {
  const { session_id, cwd } = data;
  const sessionDir = path.join(process.env.HOME, '.claude', 'sessions');
  const learningDir = path.join(process.env.HOME, '.claude', 'kailash-learning');

  // Ensure directories exist
  [sessionDir, learningDir].forEach(dir => {
    try { fs.mkdirSync(dir, { recursive: true }); } catch {}
  });

  // Load previous session if exists
  let previousSession = null;
  const sessionFile = path.join(sessionDir, `${session_id}.json`);
  const lastSessionFile = path.join(sessionDir, 'last-session.json');

  try {
    if (fs.existsSync(sessionFile)) {
      previousSession = JSON.parse(fs.readFileSync(sessionFile, 'utf8'));
    } else if (fs.existsSync(lastSessionFile)) {
      previousSession = JSON.parse(fs.readFileSync(lastSessionFile, 'utf8'));
    }
  } catch {}

  // Check for .env file
  const envExists = fs.existsSync(path.join(cwd, '.env'));

  // Initialize observations file for learning
  const observationsFile = path.join(learningDir, 'observations.jsonl');
  const observation = {
    type: 'session_start',
    session_id,
    cwd,
    timestamp: new Date().toISOString(),
    envExists
  };

  try {
    fs.appendFileSync(observationsFile, JSON.stringify(observation) + '\n');
  } catch {}

  return {
    session_id,
    cwd,
    previousSession: previousSession ? 'loaded' : 'none',
    envExists,
    message: envExists ? 'Ready' : 'WARNING: No .env file found. Ensure environment variables are set.'
  };
}
```

---

## Hook 5: session-end.js

**Purpose**: Save session state for resumption

```javascript
#!/usr/bin/env node
/**
 * Hook: session-end
 * Event: SessionEnd
 * Purpose: Save session state for future resumption
 */

const fs = require('fs');
const path = require('path');

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const result = saveSession(data);
    console.log(JSON.stringify({
      continue: true,
      hookSpecificOutput: {
        hookEventName: 'SessionEnd',
        ...result
      }
    }));
    process.exit(0);
  } catch (error) {
    console.error(`[HOOK ERROR] ${error.message}`);
    console.log(JSON.stringify({ continue: true }));
    process.exit(1);
  }
});

function saveSession(data) {
  const { session_id, cwd } = data;
  const sessionDir = path.join(process.env.HOME, '.claude', 'sessions');
  const learningDir = path.join(process.env.HOME, '.claude', 'kailash-learning');

  // Ensure directories exist
  [sessionDir, learningDir].forEach(dir => {
    try { fs.mkdirSync(dir, { recursive: true }); } catch {}
  });

  // Save session state
  const sessionData = {
    session_id,
    cwd,
    endedAt: new Date().toISOString()
  };

  try {
    // Save to session-specific file
    const sessionFile = path.join(sessionDir, `${session_id}.json`);
    fs.writeFileSync(sessionFile, JSON.stringify(sessionData, null, 2));

    // Save as last session for quick resume
    const lastSessionFile = path.join(sessionDir, 'last-session.json');
    fs.writeFileSync(lastSessionFile, JSON.stringify(sessionData, null, 2));

    // Log observation for learning
    const observationsFile = path.join(learningDir, 'observations.jsonl');
    const observation = {
      type: 'session_end',
      session_id,
      cwd,
      timestamp: new Date().toISOString()
    };
    fs.appendFileSync(observationsFile, JSON.stringify(observation) + '\n');

    return { saved: true, path: sessionFile };
  } catch (error) {
    return { saved: false, error: error.message };
  }
}
```

---

## Hook 6: pre-compact.js

**Purpose**: Save critical state before context compaction

```javascript
#!/usr/bin/env node
/**
 * Hook: pre-compact
 * Event: PreCompact
 * Purpose: Save critical context before compaction
 */

const fs = require('fs');
const path = require('path');

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const result = savePreCompactState(data);
    console.log(JSON.stringify({
      continue: true,
      hookSpecificOutput: {
        hookEventName: 'PreCompact',
        ...result
      }
    }));
    process.exit(0);
  } catch (error) {
    console.error(`[HOOK ERROR] ${error.message}`);
    console.log(JSON.stringify({ continue: true }));
    process.exit(1);
  }
});

function savePreCompactState(data) {
  const { session_id, cwd } = data;
  const checkpointDir = path.join(process.env.HOME, '.claude', 'checkpoints');
  const learningDir = path.join(process.env.HOME, '.claude', 'kailash-learning');

  // Ensure directories exist
  [checkpointDir, learningDir].forEach(dir => {
    try { fs.mkdirSync(dir, { recursive: true }); } catch {}
  });

  const checkpoint = {
    session_id,
    cwd,
    compactedAt: new Date().toISOString(),
    preservedContext: {
      // Critical items to preserve
      frameworkInUse: detectFramework(cwd),
      activeWorkflows: findActiveWorkflows(cwd)
    }
  };

  try {
    // Save checkpoint
    const checkpointFile = path.join(checkpointDir, `${session_id}-${Date.now()}.json`);
    fs.writeFileSync(checkpointFile, JSON.stringify(checkpoint, null, 2));

    // Log observation
    const observationsFile = path.join(learningDir, 'observations.jsonl');
    const observation = {
      type: 'pre_compact',
      session_id,
      timestamp: new Date().toISOString()
    };
    fs.appendFileSync(observationsFile, JSON.stringify(observation) + '\n');

    return { checkpointed: true, path: checkpointFile };
  } catch (error) {
    return { checkpointed: false, error: error.message };
  }
}

function detectFramework(cwd) {
  try {
    const files = fs.readdirSync(cwd);
    if (files.some(f => f.includes('dataflow'))) return 'dataflow';
    if (files.some(f => f.includes('nexus'))) return 'nexus';
    if (files.some(f => f.includes('kaizen'))) return 'kaizen';
    return 'core-sdk';
  } catch {
    return 'unknown';
  }
}

function findActiveWorkflows(cwd) {
  try {
    const workflows = [];
    // Look for workflow files
    const files = fs.readdirSync(cwd).filter(f => f.endsWith('.py'));
    for (const file of files.slice(0, 5)) { // Limit to first 5
      const content = fs.readFileSync(path.join(cwd, file), 'utf8');
      if (/WorkflowBuilder/.test(content)) {
        workflows.push(file);
      }
    }
    return workflows;
  } catch {
    return [];
  }
}
```

---

## Installation Commands

```bash
# 1. Create directory
mkdir -p scripts/hooks

# 2. Create each file (copy content from above)
# Or use the implementation command below

# 3. Make executable
chmod +x scripts/hooks/*.js

# 4. Test each script individually
echo '{"tool_input":{"command":"ls -la"}}' | node scripts/hooks/validate-bash-command.js
echo '{"session_id":"test","cwd":"/tmp"}' | node scripts/hooks/session-start.js
```
