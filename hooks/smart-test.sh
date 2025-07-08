#!/usr/bin/env bash
# smart-test.sh - Automatically run tests for files edited by Claude Code
#
# SYNOPSIS
#   PostToolUse hook that runs relevant tests when files are edited
#
# DESCRIPTION
#   When Claude edits a file, this hook intelligently runs associated tests:
#   - Focused tests for the specific file
#   - Package-level tests (with optional race detection)
#   - Full project tests (optional)
#   - Integration tests (if available)
#   - Configurable per-project via .claude-hooks-config.sh
#
# CONFIGURATION
#   CLAUDE_HOOKS_TEST_ON_EDIT - Enable/disable (default: true)
#   CLAUDE_HOOKS_TEST_MODES - Comma-separated: focused,package,all,integration
#   CLAUDE_HOOKS_ENABLE_RACE - Enable race detection (default: true)
#   CLAUDE_HOOKS_FAIL_ON_MISSING_TESTS - Fail if test file missing (default: false)

set -euo pipefail

# Debug trap (disabled)
# trap 'echo "DEBUG: Error on line $LINENO" >&2' ERR

# Source common helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common-helpers.sh"

# ============================================================================
# SETUP FUNCTIONS
# ============================================================================


# ============================================================================
# CONFIGURATION LOADING
# ============================================================================

load_config() {
    # Global defaults
    export CLAUDE_HOOKS_TEST_ON_EDIT="${CLAUDE_HOOKS_TEST_ON_EDIT:-true}"
    export CLAUDE_HOOKS_TEST_MODES="${CLAUDE_HOOKS_TEST_MODES:-focused,package}"
    export CLAUDE_HOOKS_ENABLE_RACE="${CLAUDE_HOOKS_ENABLE_RACE:-true}"
    export CLAUDE_HOOKS_FAIL_ON_MISSING_TESTS="${CLAUDE_HOOKS_FAIL_ON_MISSING_TESTS:-false}"
    export CLAUDE_HOOKS_TEST_VERBOSE="${CLAUDE_HOOKS_TEST_VERBOSE:-false}"

    # Load project config
    load_project_config

    # Quick exit if disabled
    if [[ "$CLAUDE_HOOKS_TEST_ON_EDIT" != "true" ]]; then
        echo "DEBUG: Test on edit disabled, exiting" >&2
        exit 0
    fi
}

# ============================================================================
# HOOK INPUT PARSING
# ============================================================================

# Check if we have input (hook mode) or running standalone (CLI mode)
if [ -t 0 ]; then
    # No input on stdin - CLI mode
    FILE_PATH="./..."
else
    # Read JSON input from stdin
    INPUT=$(cat)

    # Check if input is valid JSON
    if echo "$INPUT" | jq . >/dev/null 2>&1; then
        # Extract relevant fields
        TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
        TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty')

        # Only process edit-related tools
        if [[ ! "$TOOL_NAME" =~ ^(Edit|Write|MultiEdit)$ ]]; then
            exit 0
        fi

        # Extract file path(s)
        if [[ "$TOOL_NAME" == "MultiEdit" ]]; then
            # MultiEdit has a different structure
            FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty')
        else
            FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty')
        fi

        # Skip if no file path
        [[ -z "$FILE_PATH" ]] && exit 0
    else
        # Not valid JSON - treat as CLI mode
        FILE_PATH="./..."
    fi
fi

# Load configuration
load_config


# ============================================================================
# TEST EXCLUSION PATTERNS
# ============================================================================

should_skip_test_requirement() {
    local file="$1"
    local base=$(basename "$file")
    local dir=$(dirname "$file")

    # Files that typically don't have tests
    local skip_patterns=(
        "*.js"
    )

    # Check patterns
    for pattern in "${skip_patterns[@]}"; do
        if [[ "$base" == $pattern ]]; then
            return 0
        fi
    done

    # Skip if in specific directories
    if [[ "$dir" =~ /(vendor|testdata|examples|cmd/[^/]+|gen|generated|.gen)(/|$) ]]; then
        return 0
    fi

    # Skip if it's a test file itself (will be handled differently)
    if [[ "$file" =~ _test\.(go|py|js|ts)$ ]]; then
        return 0
    fi

    return 1
}

# ============================================================================
# TEST OUTPUT FORMATTING
# ============================================================================

format_test_output() {
    local output="$1"
    local test_type="$2"

    # If output is empty, say so
    if [[ -z "$output" ]]; then
        echo "(no output captured)"
        return
    fi

    # Show the full output - no truncation when tests fail
    echo "$output"
}

# ============================================================================
# TEST RUNNERS BY LANGUAGE
# ============================================================================

run_ruby_tests() {
    local file="$1"
    local dir=$(dirname "$file")
    local base=$(basename "$file" .rb)

    # If this IS a test file/spec, run it directly
    if [[ "$file" =~ (_spec|_test)\.rb$ ]]; then
        echo -e "${BLUE}🧪 Running test/spec file directly: $file${NC}" >&2
        local test_output

        # Determine test framework
        if [[ "$file" =~ _spec\.rb$ ]] && command -v rspec >/dev/null 2>&1; then
            # RSpec test
            if ! test_output=$(bundle exec rspec "$file" 2>&1); then
                echo -e "${RED}❌ Tests failed in $file${NC}" >&2
                echo -e "\n${RED}Failed test output:${NC}" >&2
                format_test_output "$test_output" "ruby" >&2
                return 1
            fi
        elif command -v ruby >/dev/null 2>&1; then
            # Minitest or Test::Unit
            if ! test_output=$(bundle exec ruby "$file" 2>&1); then
                echo -e "${RED}❌ Tests failed in $file${NC}" >&2
                echo -e "\n${RED}Failed test output:${NC}" >&2
                format_test_output "$test_output" "ruby" >&2
                return 1
            fi
        fi
        echo -e "${GREEN}✅ Tests passed in $file${NC}" >&2
        return 0
    fi

    # Check if we should require tests
    local require_tests="${CLAUDE_HOOKS_FAIL_ON_MISSING_TESTS:-false}"
    # Ruby files that typically don't need tests
    if [[ "$base" =~ ^(Gemfile|Rakefile|config\.ru|version)$ ]]; then
        require_tests=false
    fi
    if [[ "$dir" =~ /(db/migrate|db/schema|config|script|vendor)(/|$) ]]; then
        require_tests=false
    fi

    # Parse test modes
    IFS=',' read -ra TEST_MODES <<< "$CLAUDE_HOOKS_TEST_MODES"

    local failed=0
    local tests_run=0

    for mode in "${TEST_MODES[@]}"; do
        mode=$(echo "$mode" | xargs)  # Trim whitespace

        case "$mode" in
            "focused")
                # Look for corresponding test/spec file
                local test_files=()

                # RSpec specs
                if [[ -f "spec/${base}_spec.rb" ]]; then
                    test_files+=("spec/${base}_spec.rb")
                elif [[ -f "${dir}/spec/${base}_spec.rb" ]]; then
                    test_files+=("${dir}/spec/${base}_spec.rb")
                elif [[ -f "${dir}/../spec/${base}_spec.rb" ]]; then
                    test_files+=("${dir}/../spec/${base}_spec.rb")
                fi

                # Minitest/Test::Unit tests
                if [[ -f "test/${base}_test.rb" ]]; then
                    test_files+=("test/${base}_test.rb")
                elif [[ -f "${dir}/test/${base}_test.rb" ]]; then
                    test_files+=("${dir}/test/${base}_test.rb")
                elif [[ -f "${dir}/../test/${base}_test.rb" ]]; then
                    test_files+=("${dir}/../test/${base}_test.rb")
                fi

                if [[ ${#test_files[@]} -gt 0 ]]; then
                    for test_file in "${test_files[@]}"; do
                        echo -e "${BLUE}🧪 Running focused tests for $base...${NC}" >&2
                        tests_run=$((tests_run + 1))

                        local test_output
                        if [[ "$test_file" =~ _spec\.rb$ ]] && command -v rspec >/dev/null 2>&1; then
                            if ! test_output=$(bundle exec rspec "$test_file" 2>&1); then
                                failed=1
                                echo -e "${RED}❌ RSpec tests failed for $base${NC}" >&2
                                echo -e "\n${RED}Failed test output:${NC}" >&2
                                format_test_output "$test_output" "ruby" >&2
                                add_error "RSpec tests failed for $base"
                            fi
                        elif command -v ruby >/dev/null 2>&1; then
                            if ! test_output=$(bundle exec ruby "$test_file" 2>&1); then
                                failed=1
                                echo -e "${RED}❌ Tests failed for $base${NC}" >&2
                                echo -e "\n${RED}Failed test output:${NC}" >&2
                                format_test_output "$test_output" "ruby" >&2
                                add_error "Tests failed for $base"
                            fi
                        fi
                    done
                elif [[ "$require_tests" == "true" ]]; then
                    echo -e "${RED}❌ Missing required test file for $base${NC}" >&2
                    echo -e "${YELLOW}📝 This file should have tests!${NC}" >&2
                    add_error "Missing required test file for $base"
                    return 2
                fi
                ;;

            "package")
                # Run all tests in the current directory/module
                echo -e "${BLUE}📦 Running package tests...${NC}" >&2
                tests_run=$((tests_run + 1))

                local test_output
                # Try RSpec first
                if command -v rspec >/dev/null 2>&1 && [[ -d "spec" ]]; then
                    if ! test_output=$(bundle exec rspec 2>&1); then
                        failed=1
                        echo -e "${RED}❌ RSpec tests failed${NC}" >&2
                        echo -e "\n${RED}Failed test output:${NC}" >&2
                        format_test_output "$test_output" "ruby" >&2
                        add_error "RSpec tests failed"
                    fi
                # Try Rails test
                elif [[ -f "bin/rails" ]] && [[ -d "test" ]]; then
                    if ! test_output=$(bundle exec rails test 2>&1); then
                        failed=1
                        echo -e "${RED}❌ Rails tests failed${NC}" >&2
                        echo -e "\n${RED}Failed test output:${NC}" >&2
                        format_test_output "$test_output" "ruby" >&2
                        add_error "Rails tests failed"
                    fi
                # Try rake test
                elif command -v rake >/dev/null 2>&1 && grep -q "test" Rakefile 2>/dev/null; then
                    if ! test_output=$(bundle exec rake test 2>&1); then
                        failed=1
                        echo -e "${RED}❌ Rake tests failed${NC}" >&2
                        echo -e "\n${RED}Failed test output:${NC}" >&2
                        format_test_output "$test_output" "ruby" >&2
                        add_error "Rake tests failed"
                    fi
                fi
                ;;

            "all")
                # Run all project tests
                echo -e "${BLUE}🌍 Running all project tests...${NC}" >&2
                tests_run=$((tests_run + 1))

                local test_output
                # Try RSpec
                if command -v rspec >/dev/null 2>&1 && [[ -d "spec" ]]; then
                    if ! test_output=$(bundle exec rspec 2>&1); then
                        failed=1
                        echo -e "${RED}❌ All RSpec tests failed${NC}" >&2
                        echo -e "\n${RED}Failed test output:${NC}" >&2
                        format_test_output "$test_output" "ruby" >&2
                        add_error "All RSpec tests failed"
                    fi
                # Try Rails test
                elif [[ -f "bin/rails" ]] && [[ -d "test" ]]; then
                    if ! test_output=$(bundle exec rails test 2>&1); then
                        failed=1
                        echo -e "${RED}❌ All Rails tests failed${NC}" >&2
                        echo -e "\n${RED}Failed test output:${NC}" >&2
                        format_test_output "$test_output" "ruby" >&2
                        add_error "All Rails tests failed"
                    fi
                fi
                ;;
        esac
    done

    # Summary
    if [[ $tests_run -eq 0 ]]; then
        if [[ "$require_tests" == "true" ]]; then
            echo -e "${RED}❌ No tests found for $file (tests required)${NC}" >&2
            add_error "No tests found for $file (tests required)"
            return 2
        elif [[ "$CLAUDE_HOOKS_TEST_VERBOSE" == "true" ]]; then
            echo -e "${YELLOW}⚠️  No tests run for $file${NC}" >&2
        fi
    elif [[ $failed -eq 0 ]]; then
        log_success "All tests passed for $file"
    fi

    return $failed
}

run_python_tests() {
    local file="$1"
    local dir=$(dirname "$file")
    local base=$(basename "$file" .py)

    # If this IS a test file, run it directly
    if [[ "$file" =~ (test_.*|.*_test)\.py$ ]]; then
        echo -e "${BLUE}🧪 Running test file directly: $file${NC}" >&2
        local test_output
        if command -v pytest >/dev/null 2>&1; then
            if ! test_output=$(
                pytest -xvs "$file" 2>&1); then
                echo -e "${RED}❌ Tests failed in $file${NC}" >&2
                echo -e "\n${RED}Failed test output:${NC}" >&2
                format_test_output "$test_output" "python" >&2
                return 1
            fi
        elif command -v python >/dev/null 2>&1; then
            if ! test_output=$(
                python -m unittest "$file" 2>&1); then
                echo -e "${RED}❌ Tests failed in $file${NC}" >&2
                echo -e "\n${RED}Failed test output:${NC}" >&2
                format_test_output "$test_output" "python" >&2
                return 1
            fi
        fi
        echo -e "${GREEN}✅ Tests passed in $file${NC}" >&2
        return 0
    fi

    # Check if we should require tests
    local require_tests="${CLAUDE_HOOKS_FAIL_ON_MISSING_TESTS:-false}"
    # Python files that typically don't need tests
    if [[ "$base" =~ ^(__init__|__main__|setup|setup.py|conf|config|settings)$ ]]; then
        require_tests=false
    fi
    if [[ "$dir" =~ /(migrations|scripts|docs|examples)(/|$) ]]; then
        require_tests=false
    fi

    # Find test file
    local test_file=""
    local test_candidates=(
        "${dir}/test_${base}.py"
        "${dir}/${base}_test.py"
        "${dir}/tests/test_${base}.py"
        "${dir}/../tests/test_${base}.py"
    )

    for candidate in "${test_candidates[@]}"; do
        if [[ -f "$candidate" ]]; then
            test_file="$candidate"
            break
        fi
    done

    local failed=0
    local tests_run=0

    # Parse test modes
    IFS=',' read -ra TEST_MODES <<< "$CLAUDE_HOOKS_TEST_MODES"

    for mode in "${TEST_MODES[@]}"; do
        mode=$(echo "$mode" | xargs)

        case "$mode" in
            "focused")
                if [[ -n "$test_file" ]]; then
                    echo -e "${BLUE}🧪 Running focused tests for $base...${NC}" >&2
                    tests_run=$((tests_run + 1))

                    local test_output
                    if command -v pytest >/dev/null 2>&1; then
                        if ! test_output=$(
                            pytest -xvs "$test_file" -k "$base" 2>&1); then
                            failed=1
                            echo -e "${RED}❌ Focused tests failed for $base${NC}" >&2
                            echo -e "\n${RED}Failed test output:${NC}" >&2
                            format_test_output "$test_output" "python" >&2
                            add_error "Focused tests failed for $base"
                        fi
                    elif command -v python >/dev/null 2>&1; then
                        if ! test_output=$(
                            python -m unittest "$test_file" 2>&1); then
                            failed=1
                            echo -e "${RED}❌ Focused tests failed for $base${NC}" >&2
                            echo -e "\n${RED}Failed test output:${NC}" >&2
                            format_test_output "$test_output" "python" >&2
                            add_error "Focused tests failed for $base"
                        fi
                    fi
                elif [[ "$require_tests" == "true" ]]; then
                    echo -e "${RED}❌ Missing required test file for: $file${NC}" >&2
                    echo -e "${YELLOW}📝 Expected one of: ${test_candidates[*]}${NC}" >&2
                    add_error "Missing required test file for: $file"
                    return 2
                fi
                ;;

            "package")
                echo -e "${BLUE}📦 Running package tests in $dir...${NC}" >&2
                tests_run=$((tests_run + 1))

                if command -v pytest >/dev/null 2>&1; then
                    local test_output
                    if ! test_output=$(
                        pytest -xvs "$dir" 2>&1); then
                        failed=1
                        echo -e "${RED}❌ Package tests failed in $dir${NC}" >&2
                        echo -e "\n${RED}Failed test output:${NC}" >&2
                        format_test_output "$test_output" "python" >&2
                        add_error "Package tests failed in $dir"
                    fi
                fi
                ;;
        esac
    done

    # Summary
    if [[ $tests_run -eq 0 && "$require_tests" == "true" && -z "$test_file" ]]; then
        echo -e "${RED}❌ No tests found for $file (tests required)${NC}" >&2
        add_error "No tests found for $file (tests required)"
        return 2
    elif [[ $failed -eq 0 && $tests_run -gt 0 ]]; then
        log_success "All tests passed for $file"
    fi

    return $failed
}

run_javascript_tests() {
    local file="$1"
    local dir=$(dirname "$file")
    local base=$(basename "$file" | sed 's/\.[tj]sx\?$//' | sed 's/\.(test|spec)$//')

    # If this IS a test file, run it directly
    if [[ "$file" =~ \.(test|spec)\.[tj]sx?$ ]]; then
        echo -e "${BLUE}🧪 Running test file directly: $file${NC}" >&2

        local test_output
        if [[ -f "package.json" ]] && jq -e '.scripts.test' package.json >/dev/null 2>&1; then
            if ! test_output=$(
                npm test -- "$file" 2>&1); then
                echo -e "${RED}❌ Tests failed in $file${NC}" >&2
                echo -e "\n${RED}Failed test output:${NC}" >&2
                format_test_output "$test_output" "javascript" >&2
                return 1
            fi
        elif command -v jest >/dev/null 2>&1; then
            if ! test_output=$(
                jest "$file" 2>&1); then
                echo -e "${RED}❌ Tests failed in $file${NC}" >&2
                echo -e "\n${RED}Failed test output:${NC}" >&2
                format_test_output "$test_output" "javascript" >&2
                return 1
            fi
        fi
        echo -e "${GREEN}✅ Tests passed in $file${NC}" >&2
        return 0
    fi

    # Check if we should require tests
    local require_tests="${CLAUDE_HOOKS_FAIL_ON_MISSING_TESTS:-false}"
    # JS/TS files that typically don't need tests
    if [[ "$base" =~ ^(index|main|app|config|setup|webpack\.config|rollup\.config|vite\.config)$ ]]; then
        require_tests=false
    fi
    if [[ "$dir" =~ /(dist|build|node_modules|coverage|docs|examples|scripts)(/|$) ]]; then
        require_tests=false
    fi
    # Skip declaration files
    if [[ "$file" =~ \.d\.ts$ ]]; then
        require_tests=false
    fi

    # Find test file
    local test_file=""
    local test_candidates=(
        "${dir}/${base}.test.js"
        "${dir}/${base}.spec.js"
        "${dir}/${base}.test.ts"
        "${dir}/${base}.spec.ts"
        "${dir}/${base}.test.jsx"
        "${dir}/${base}.test.tsx"
        "${dir}/__tests__/${base}.test.js"
        "${dir}/__tests__/${base}.spec.js"
        "${dir}/__tests__/${base}.test.ts"
    )

    for candidate in "${test_candidates[@]}"; do
        if [[ -f "$candidate" ]]; then
            test_file="$candidate"
            break
        fi
    done

    local failed=0
    local tests_run=0

    # Check if package.json has test script
    if [[ -f "package.json" ]] && jq -e '.scripts.test' package.json >/dev/null 2>&1; then
        # Parse test modes
        IFS=',' read -ra TEST_MODES <<< "$CLAUDE_HOOKS_TEST_MODES"

        for mode in "${TEST_MODES[@]}"; do
            mode=$(echo "$mode" | xargs)

            case "$mode" in
                "focused")
                    if [[ -n "$test_file" ]]; then
                        echo -e "${BLUE}🧪 Running focused tests for $base...${NC}" >&2
                        tests_run=$((tests_run + 1))

                        local test_output
                        if ! test_output=$(
                            npm test -- "$test_file" 2>&1); then
                            failed=1
                            echo -e "${RED}❌ Focused tests failed for $base${NC}" >&2
                            echo -e "\n${RED}Failed test output:${NC}" >&2
                            format_test_output "$test_output" "javascript" >&2
                            add_error "Focused tests failed for $base"
                        fi
                    elif [[ "$require_tests" == "true" ]]; then
                        echo -e "${RED}❌ Missing required test file for: $file${NC}" >&2
                        echo -e "${YELLOW}📝 Expected one of: ${test_candidates[*]}${NC}" >&2
                        add_error "Missing required test file for: $file"
                        return 2
                    fi
                    ;;

                "package")
                    echo -e "${BLUE}📦 Running all tests...${NC}" >&2
                    tests_run=$((tests_run + 1))

                    local test_output
                    if ! test_output=$(
                        npm test 2>&1); then
                        failed=1
                        echo -e "${RED}❌ Package tests failed${NC}" >&2
                        echo -e "\n${RED}Failed test output:${NC}" >&2
                        format_test_output "$test_output" "javascript" >&2
                        add_error "Package tests failed"
                    fi
                    ;;
            esac
        done
    elif [[ "$require_tests" == "true" && -z "$test_file" ]]; then
        echo -e "${RED}❌ No test runner configured and no tests found${NC}" >&2
        add_error "No test runner configured and no tests found"
        return 2
    fi

    # Summary
    if [[ $tests_run -eq 0 && "$require_tests" == "true" && -z "$test_file" ]]; then
        echo -e "${RED}❌ No tests found for $file (tests required)${NC}" >&2
        add_error "No tests found for $file (tests required)"
        return 2
    elif [[ $failed -eq 0 && $tests_run -gt 0 ]]; then
        log_success "All tests passed for $file"
    fi

    return $failed
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Determine file type and run appropriate tests
main() {
    # Print header
    print_test_header

    local failed=0

    # Language-specific test runners
    if [[ "$FILE_PATH" =~ \.rb$ ]]; then
        run_ruby_tests "$FILE_PATH" || failed=1
    elif [[ "$FILE_PATH" =~ \.py$ ]]; then
        run_python_tests "$FILE_PATH" || failed=1
    elif [[ "$FILE_PATH" =~ \.[jt]sx?$ ]]; then
        run_javascript_tests "$FILE_PATH" || failed=1
    else
        # No tests for this file type
        exit 0
    fi

    if [[ $failed -ne 0 ]]; then
        exit_with_test_failure "$FILE_PATH"
    else
        exit_with_success_message "Tests pass. Continue with your task."
    fi
}

# Run main
main
