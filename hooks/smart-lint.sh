#!/usr/bin/env bash
# smart-lint.sh - Intelligent project-aware code quality checks for Claude Code
#
# SYNOPSIS
#   smart-lint.sh [options]
#
# DESCRIPTION
#   Automatically detects project type and runs ALL quality checks.
#   Every issue found is blocking - code must be 100% clean to proceed.
#
# OPTIONS
#   --debug       Enable debug output
#   --fast        Skip slow checks (import cycles, security scans)
#
# EXIT CODES
#   0 - Success (all checks passed - everything is ✅ GREEN)
#   1 - General error (missing dependencies, etc.)
#   2 - ANY issues found - ALL must be fixed
#
# CONFIGURATION
#   Project-specific overrides can be placed in .claude-hooks-config.sh
#   See inline documentation for all available options.

# Don't use set -e - we need to control exit codes carefully
set +e

# ============================================================================
# COLOR DEFINITIONS AND UTILITIES
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Debug mode
CLAUDE_HOOKS_DEBUG="${CLAUDE_HOOKS_DEBUG:-0}"

# Logging functions
log_debug() {
    [[ "$CLAUDE_HOOKS_DEBUG" == "1" ]] && echo -e "${CYAN}[DEBUG]${NC} $*" >&2
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*" >&2
}

# Performance timing
time_start() {
    if [[ "$CLAUDE_HOOKS_DEBUG" == "1" ]]; then
        echo $(($(date +%s%N)/1000000))
    fi
}

time_end() {
    if [[ "$CLAUDE_HOOKS_DEBUG" == "1" ]]; then
        local start=$1
        local end=$(($(date +%s%N)/1000000))
        local duration=$((end - start))
        log_debug "Execution time: ${duration}ms"
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# ============================================================================
# PROJECT DETECTION
# ============================================================================

detect_project_type() {
    local project_type="unknown"
    local types=()
    
    # Ruby/Rails project
    if [[ -f "Gemfile" ]] || [[ -f "Gemfile.lock" ]] || [[ -f ".ruby-version" ]] || [[ -n "$(find . -maxdepth 3 -name "*.rb" -type f -print -quit 2>/dev/null)" ]]; then
        types+=("ruby")
    fi
    
    # Python project
    if [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -f "requirements.txt" ]] || [[ -n "$(find . -maxdepth 3 -name "*.py" -type f -print -quit 2>/dev/null)" ]]; then
        types+=("python")
    fi
    
    # JavaScript/TypeScript project
    if [[ -f "package.json" ]] || [[ -f "tsconfig.json" ]] || [[ -n "$(find . -maxdepth 3 \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \) -type f -print -quit 2>/dev/null)" ]]; then
        types+=("javascript")
    fi
    
    # Rust project
    if [[ -f "Cargo.toml" ]] || [[ -n "$(find . -maxdepth 3 -name "*.rs" -type f -print -quit 2>/dev/null)" ]]; then
        types+=("rust")
    fi
    
    
    # Return primary type or "mixed" if multiple
    if [[ ${#types[@]} -eq 1 ]]; then
        project_type="${types[0]}"
    elif [[ ${#types[@]} -gt 1 ]]; then
        project_type="mixed:$(IFS=,; echo "${types[*]}")"
    fi
    
    log_debug "Detected project type: $project_type"
    echo "$project_type"
}

# Get list of modified files (if available from git)
get_modified_files() {
    if [[ -d .git ]] && command_exists git; then
        # Get files modified in the last commit or currently staged/modified
        git diff --name-only HEAD 2>/dev/null || true
        git diff --cached --name-only 2>/dev/null || true
    fi
}

# Check if we should skip a file
should_skip_file() {
    local file="$1"
    
    # Check .claude-hooks-ignore if it exists
    if [[ -f ".claude-hooks-ignore" ]]; then
        while IFS= read -r pattern; do
            # Skip comments and empty lines
            [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
            
            # Check if file matches pattern
            if [[ "$file" == $pattern ]]; then
                log_debug "Skipping $file due to .claude-hooks-ignore pattern: $pattern"
                return 0
            fi
        done < ".claude-hooks-ignore"
    fi
    
    # Check for inline skip comments
    if [[ -f "$file" ]] && head -n 5 "$file" 2>/dev/null | grep -q "claude-hooks-disable"; then
        log_debug "Skipping $file due to inline claude-hooks-disable comment"
        return 0
    fi
    
    return 1
}

# ============================================================================
# ERROR TRACKING
# ============================================================================

declare -a CLAUDE_HOOKS_SUMMARY=()
declare -i CLAUDE_HOOKS_ERROR_COUNT=0

add_error() {
    local message="$1"
    CLAUDE_HOOKS_ERROR_COUNT+=1
    CLAUDE_HOOKS_SUMMARY+=("${RED}❌${NC} $message")
}

print_summary() {
    if [[ $CLAUDE_HOOKS_ERROR_COUNT -gt 0 ]]; then
        # Only show failures when there are errors
        echo -e "\n${BLUE}═══ Summary ═══${NC}" >&2
        for item in "${CLAUDE_HOOKS_SUMMARY[@]}"; do
            echo -e "$item" >&2
        done
        
        echo -e "\n${RED}Found $CLAUDE_HOOKS_ERROR_COUNT issue(s) that MUST be fixed!${NC}" >&2
        echo -e "${RED}════════════════════════════════════════════${NC}" >&2
        echo -e "${RED}❌ ALL ISSUES ARE BLOCKING ❌${NC}" >&2
        echo -e "${RED}════════════════════════════════════════════${NC}" >&2
        echo -e "${RED}Fix EVERYTHING above until all checks are ✅ GREEN${NC}" >&2
    fi
}

# ============================================================================
# CONFIGURATION LOADING
# ============================================================================

load_config() {
    # Default configuration
    export CLAUDE_HOOKS_ENABLED="${CLAUDE_HOOKS_ENABLED:-true}"
    export CLAUDE_HOOKS_FAIL_FAST="${CLAUDE_HOOKS_FAIL_FAST:-false}"
    export CLAUDE_HOOKS_SHOW_TIMING="${CLAUDE_HOOKS_SHOW_TIMING:-false}"
    
    # Language enables
    export CLAUDE_HOOKS_RUBY_ENABLED="${CLAUDE_HOOKS_RUBY_ENABLED:-true}"
    export CLAUDE_HOOKS_PYTHON_ENABLED="${CLAUDE_HOOKS_PYTHON_ENABLED:-true}"
    export CLAUDE_HOOKS_JS_ENABLED="${CLAUDE_HOOKS_JS_ENABLED:-true}"
    export CLAUDE_HOOKS_RUST_ENABLED="${CLAUDE_HOOKS_RUST_ENABLED:-true}"
    
    # Project-specific overrides
    if [[ -f ".claude-hooks-config.sh" ]]; then
        source ".claude-hooks-config.sh" || {
            log_error "Failed to load .claude-hooks-config.sh"
            exit 2
        }
    fi
    
    # Quick exit if hooks are disabled
    if [[ "$CLAUDE_HOOKS_ENABLED" != "true" ]]; then
        log_info "Claude hooks are disabled"
        exit 0
    fi
}


# ============================================================================
# RUBY/RAILS LINTING
# ============================================================================

lint_ruby() {
    if [[ "${CLAUDE_HOOKS_RUBY_ENABLED:-true}" != "true" ]]; then
        log_debug "Ruby linting disabled"
        return 0
    fi
    
    log_info "Running Ruby/Rails linters..."
    
    # Check if we have Ruby files
    if ! find . -name "*.rb" -type f -print -quit 2>/dev/null | grep -q . && ! [[ -f "Gemfile" ]]; then
        log_debug "No Ruby files found, skipping Ruby checks"
        return 0
    fi
    
    # RuboCop for code style and linting
    if command_exists rubocop; then
        log_info "Running RuboCop..."
        local rubocop_output
        # Use autocorrect mode to fix issues automatically
        if ! rubocop_output=$(bundle exec rubocop --autocorrect-all 2>&1); then
            # Check if there are still unfixed issues
            if ! bundle exec rubocop --format quiet >/dev/null 2>&1; then
                add_error "RuboCop found issues that couldn't be auto-fixed"
                echo "$rubocop_output" >&2
            fi
        fi
    elif [[ -f "Gemfile" ]] && grep -q "rubocop" Gemfile; then
        log_error "RuboCop is in Gemfile but not available - run 'bundle install'"
        add_error "RuboCop not available"
    fi
    
    # ERB linting for Rails views
    if command_exists erb_lint; then
        log_info "Running ERB Lint..."
        local erb_output
        if ! erb_output=$(bundle exec erb_lint --autocorrect 2>&1); then
            # Check if there are still issues
            if ! bundle exec erb_lint --format compact >/dev/null 2>&1; then
                add_error "ERB Lint found issues"
                echo "$erb_output" >&2
            fi
        fi
    fi
    
    # Rails best practices
    if command_exists rails_best_practices; then
        log_info "Running Rails Best Practices..."
        local rbp_output
        if ! rbp_output=$(bundle exec rails_best_practices . 2>&1); then
            add_error "Rails Best Practices found issues"
            echo "$rbp_output" >&2
        fi
    fi
    
    # Bundle audit for security vulnerabilities
    if command_exists bundle-audit; then
        log_info "Running bundle audit..."
        local audit_output
        if ! audit_output=$(bundle exec bundle-audit check --update 2>&1); then
            add_error "Security vulnerabilities found in dependencies"
            echo "$audit_output" >&2
        fi
    fi
    
    return 0
}

# ============================================================================
# OTHER LANGUAGE LINTERS
# ============================================================================

lint_python() {
    if [[ "${CLAUDE_HOOKS_PYTHON_ENABLED:-true}" != "true" ]]; then
        log_debug "Python linting disabled"
        return 0
    fi
    
    log_info "Running Python linters..."
    
    # Black formatting
    if command_exists black; then
        local black_output
        if ! black_output=$(black . --check 2>&1); then
            # Apply formatting and capture any errors
            local format_output
            if ! format_output=$(black . 2>&1); then
                add_error "Python formatting failed"
                echo "$format_output" >&2
            fi
        fi
    fi
    
    # Linting
    if command_exists ruff; then
        local ruff_output
        if ! ruff_output=$(ruff check --fix . 2>&1); then
            add_error "Ruff found issues"
            echo "$ruff_output" >&2
        fi
    elif command_exists flake8; then
        local flake8_output
        if ! flake8_output=$(flake8 . 2>&1); then
            add_error "Flake8 found issues"
            echo "$flake8_output" >&2
        fi
    fi
    
    return 0
}

lint_javascript() {
    if [[ "${CLAUDE_HOOKS_JS_ENABLED:-true}" != "true" ]]; then
        log_debug "JavaScript linting disabled"
        return 0
    fi
    
    log_info "Running JavaScript/TypeScript linters..."
    
    # Check if we have JavaScript/TypeScript files
    if ! find . -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" -o -name "*.mjs" -o -name "*.cjs" | grep -q . && ! [[ -f "package.json" ]]; then
        log_debug "No JavaScript/TypeScript files found, skipping checks"
        return 0
    fi
    
    # TypeScript compilation check
    if [[ -f "tsconfig.json" ]]; then
        if command_exists tsc || (command_exists npx && npx tsc --version >/dev/null 2>&1); then
            log_info "Running TypeScript compiler..."
            local tsc_output
            local tsc_cmd="tsc --noEmit"
            
            # Check if we should use npx
            if ! command_exists tsc; then
                tsc_cmd="npx tsc --noEmit"
            fi
            
            if ! tsc_output=$($tsc_cmd 2>&1); then
                add_error "TypeScript compilation errors found"
                echo "$tsc_output" >&2
            fi
        elif [[ -f "package.json" ]] && grep -q "typescript" package.json; then
            log_error "TypeScript is in package.json but tsc not available - run 'npm install'"
            add_error "TypeScript compiler not available"
        fi
    fi
    
    # ESLint - comprehensive JavaScript/TypeScript linting
    if [[ -f ".eslintrc.js" ]] || [[ -f ".eslintrc.json" ]] || [[ -f ".eslintrc.yml" ]] || [[ -f "eslint.config.js" ]] || ([[ -f "package.json" ]] && grep -q "eslintConfig" package.json); then
        if command_exists eslint || (command_exists npx && npx eslint --version >/dev/null 2>&1); then
            log_info "Running ESLint..."
            local eslint_output
            local eslint_cmd="eslint . --ext .js,.jsx,.ts,.tsx,.mjs,.cjs"
            
            # Check if we should use npx
            if ! command_exists eslint; then
                eslint_cmd="npx eslint . --ext .js,.jsx,.ts,.tsx,.mjs,.cjs"
            fi
            
            # Try to fix automatically first
            if ! eslint_output=$($eslint_cmd --fix 2>&1); then
                # Check if there are still unfixed issues
                if ! $eslint_cmd >/dev/null 2>&1; then
                    add_error "ESLint found issues that couldn't be auto-fixed"
                    echo "$eslint_output" >&2
                fi
            fi
        elif [[ -f "package.json" ]] && grep -q "eslint" package.json; then
            # Try npm run lint as fallback
            if npm run lint --if-present >/dev/null 2>&1; then
                local lint_output
                if ! lint_output=$(npm run lint 2>&1); then
                    add_error "ESLint found issues (via npm run lint)"
                    echo "$lint_output" >&2
                fi
            else
                log_error "ESLint is in package.json but not available - run 'npm install'"
                add_error "ESLint not available"
            fi
        fi
    fi
    
    # Prettier - code formatting
    if [[ -f ".prettierrc" ]] || [[ -f "prettier.config.js" ]] || [[ -f ".prettierrc.json" ]] || [[ -f ".prettierrc.yml" ]] || ([[ -f "package.json" ]] && grep -q "prettier" package.json); then
        if command_exists prettier || (command_exists npx && npx prettier --version >/dev/null 2>&1); then
            log_info "Running Prettier..."
            local prettier_cmd="prettier"
            
            # Check if we should use npx
            if ! command_exists prettier; then
                prettier_cmd="npx prettier"
            fi
            
            # Apply formatting
            local format_output
            if ! format_output=$($prettier_cmd --write . 2>&1); then
                add_error "Prettier formatting failed"
                echo "$format_output" >&2
            fi
        elif [[ -f "package.json" ]] && grep -q "prettier" package.json; then
            log_error "Prettier is in package.json but not available - run 'npm install'"
            add_error "Prettier not available"
        fi
    fi
    
    # Check for console.log statements in production code
    if [[ "${CLAUDE_HOOKS_JS_NO_CONSOLE:-true}" == "true" ]]; then
        log_info "Checking for console.log statements..."
        local console_found=false
        
        # Exclude test files, config files, and node_modules
        if grep -r --include="*.js" --include="*.jsx" --include="*.ts" --include="*.tsx" "console\.\(log\|debug\|info\|warn\|error\)" . | \
           grep -v -E "(test\.|spec\.|\.test\.|\.spec\.|__tests__|node_modules|\.config\.|dist/|build/)" | \
           grep -v "// *eslint-disable.*console" | \
           head -20; then
            console_found=true
            add_error "Found console statements in production code"
        fi
    fi
    
    return 0
}

lint_rust() {
    if [[ "${CLAUDE_HOOKS_RUST_ENABLED:-true}" != "true" ]]; then
        log_debug "Rust linting disabled"
        return 0
    fi
    
    log_info "Running Rust linters..."
    
    if command_exists cargo; then
        local fmt_output
        if ! fmt_output=$(cargo fmt -- --check 2>&1); then
            # Apply formatting and capture any errors
            local format_output
            if ! format_output=$(cargo fmt 2>&1); then
                add_error "Rust formatting failed"
                echo "$format_output" >&2
            fi
        fi
        
        local clippy_output
        if ! clippy_output=$(cargo clippy --quiet -- -D warnings 2>&1); then
            add_error "Clippy found issues"
            echo "$clippy_output" >&2
        fi
    else
        log_info "Cargo not found, skipping Rust checks"
    fi
    
    return 0
}


# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Parse command line options
FAST_MODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            export CLAUDE_HOOKS_DEBUG=1
            shift
            ;;
        --fast)
            FAST_MODE=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 2
            ;;
    esac
done

# Print header
echo "" >&2
echo "🔍 Style Check - Validating code formatting..." >&2
echo "────────────────────────────────────────────" >&2

# Load configuration
load_config

# Start timing
START_TIME=$(time_start)

# Detect project type
PROJECT_TYPE=$(detect_project_type)
log_info "Project type: $PROJECT_TYPE"

# Main execution
main() {
    # Handle mixed project types
    if [[ "$PROJECT_TYPE" == mixed:* ]]; then
        local types="${PROJECT_TYPE#mixed:}"
        IFS=',' read -ra TYPE_ARRAY <<< "$types"
        
        for type in "${TYPE_ARRAY[@]}"; do
            case "$type" in
                "ruby") lint_ruby ;;
                "python") lint_python ;;
                "javascript") lint_javascript ;;
                "rust") lint_rust ;;
            esac
            
            # Fail fast if configured
            if [[ "$CLAUDE_HOOKS_FAIL_FAST" == "true" && $CLAUDE_HOOKS_ERROR_COUNT -gt 0 ]]; then
                break
            fi
        done
    else
        # Single project type
        case "$PROJECT_TYPE" in
            "ruby") lint_ruby ;;
            "python") lint_python ;;
            "javascript") lint_javascript ;;
            "rust") lint_rust ;;
            "unknown") 
                log_info "No recognized project type, skipping checks"
                ;;
        esac
    fi
    
    # Show timing if enabled
    time_end "$START_TIME"
    
    # Print summary
    print_summary
    
    # Return exit code - any issues mean failure
    if [[ $CLAUDE_HOOKS_ERROR_COUNT -gt 0 ]]; then
        return 2
    else
        return 0
    fi
}

# Run main function
main
exit_code=$?

# Final message and exit
if [[ $exit_code -eq 2 ]]; then
    echo -e "\n${RED}🛑 FAILED - Fix all issues above! 🛑${NC}" >&2
    echo -e "${YELLOW}📋 NEXT STEPS:${NC}" >&2
    echo -e "${YELLOW}  1. Fix the issues listed above${NC}" >&2
    echo -e "${YELLOW}  2. Verify the fix by running the lint command again${NC}" >&2
    echo -e "${YELLOW}  3. Continue with your original task${NC}" >&2
    exit 2
else
    # Always exit with 2 so Claude sees the continuation message
    echo -e "\n${YELLOW}👉 Style clean. Continue with your task.${NC}" >&2
    exit 2
fi