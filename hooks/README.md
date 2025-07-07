# Claude Code Hooks

Automated code quality checks that run after Claude Code modifies files, enforcing project standards with zero tolerance for errors.

## Hooks

### `smart-lint.sh`
Intelligent project-aware linting that automatically detects language and runs appropriate checks:
- **Ruby/Rails**: `rubocop` (with auto-fix), `erb_lint`, `rails_best_practices`, `bundle-audit`
- **Python**: `black`, `ruff` or `flake8`
- **JavaScript/TypeScript**: `tsc` (type checking), `eslint` (with auto-fix), `prettier`, console.log detection
- **Rust**: `cargo fmt`, `cargo clippy`

Features:
- Detects project type automatically
- Respects project-specific Makefiles (`make lint`)
- Smart file filtering (only checks modified files)
- Fast mode available (`--fast` to skip slow checks)
- Exit code 2 means issues found - ALL must be fixed

#### Failure

```
> Edit operation feedback:
  - [~/.claude/hooks/smart-lint.sh]:
  🔍 Style Check - Validating code formatting...
  ────────────────────────────────────────────
  [INFO] Project type: ruby
  [INFO] Running Ruby/Rails linters...
  [INFO] Running RuboCop...

  ═══ Summary ═══
  ❌ RuboCop found issues that couldn't be auto-fixed

  Found 1 issue(s) that MUST be fixed!
  ════════════════════════════════════════════
  ❌ ALL ISSUES ARE BLOCKING ❌
  ════════════════════════════════════════════
  Fix EVERYTHING above until all checks are ✅ GREEN

  🛑 FAILED - Fix all issues above! 🛑
  📋 NEXT STEPS:
    1. Fix the issues listed above
    2. Verify the fix by running the lint command again
    3. Continue with your original task
```
```

#### Success

```
> Task operation feedback:
  - [~/.claude/hooks/smart-lint.sh]:
  🔍 Style Check - Validating code formatting...
  ────────────────────────────────────────────
  [INFO] Project type: ruby
  [INFO] Running Ruby/Rails linters...
  [INFO] Running RuboCop...

  👉 Style clean. Continue with your task.
```
```

By `exit 2` on success and telling it to continue, we prevent Claude from stopping after it has corrected
the style issues.

### `ntfy-notifier.sh`
Push notifications via ntfy service for Claude Code events:
- Sends alerts when Claude finishes tasks
- Includes terminal context (tmux/Terminal window name) for identification
- Requires `~/.config/claude-code-ntfy/config.yaml` with topic configuration

### `smart-test.sh`
Automatically runs relevant tests when files are edited:
- **Ruby/Rails**: `rspec`, `rails test`, `rake test` (supports focused, package, and all test modes)
- **Python**: `pytest`, `unittest`
- **JavaScript/TypeScript**: `jest`, `vitest`, npm test scripts

Features:
- Detects test framework automatically
- Runs focused tests for edited files
- Configurable test modes (focused, package, all)
- Smart test file detection

## Installation

Hooks are installed to `~/.claude/hooks/`

## Configuration

### Global Settings
Set environment variables or create project-specific `.claude-hooks-config.sh`:

```bash
CLAUDE_HOOKS_ENABLED=false      # Disable all hooks
CLAUDE_HOOKS_DEBUG=1            # Enable debug output
```

### Per-Project Settings
Create `.claude-hooks-config.sh` in your project root:

```bash
# Language-specific options
CLAUDE_HOOKS_RUBY_ENABLED=false
CLAUDE_HOOKS_PYTHON_ENABLED=false
CLAUDE_HOOKS_JS_ENABLED=false

# Ruby/Rails specific
CLAUDE_HOOKS_RUBOCOP_CONFIG=".rubocop.yml"
CLAUDE_HOOKS_RSPEC_OPTIONS="--format documentation"

# TypeScript/JavaScript specific
CLAUDE_HOOKS_ESLINT_CONFIG=".eslintrc.js"
CLAUDE_HOOKS_TSC_STRICT=true
CLAUDE_HOOKS_JS_NO_CONSOLE=true

# See example-claude-hooks-config.sh for all options
```

### Excluding Files
Create `.claude-hooks-ignore` in your project root using gitignore syntax:

```
vendor/**
node_modules/**
db/schema.rb
db/migrate/**
*.min.js
build/**
dist/**
```

Add `// claude-hooks-disable` to the top of any file to skip hooks.

## Usage

```bash
./smart-lint.sh           # Auto-runs after Claude edits
./smart-lint.sh --debug   # Debug mode
./smart-lint.sh --fast    # Skip slow checks
```

### Exit Codes
- `0`: All checks passed ✅
- `1`: General error (missing dependencies)
- `2`: Issues found - must fix ALL

## Dependencies

Hooks work best with these tools installed:
- **Ruby/Rails**: `rubocop`, `erb_lint`, `rails_best_practices`, `rspec`
- **Python**: `black`, `ruff`, `pytest`
- **JavaScript/TypeScript**: `typescript`, `eslint`, `prettier`
- **Rust**: `cargo fmt`, `cargo clippy`
- **General**: `yq` (for ntfy config parsing)

Hooks gracefully degrade if tools aren't installed.
