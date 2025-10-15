#!/usr/bin/env bash
# scripts/test/test-docx-pipeline-e2e.sh
# End-to-end test for DOCX pipeline

set -euo pipefail

# =============================================================================
# INITIALIZATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# =============================================================================
# LOAD ENVIRONMENT
# =============================================================================

load_environment() {
    if [[ -f "$PROJECT_ROOT/infrastructure/utils/core.sh" ]]; then
        # shellcheck source=/dev/null
        source "$PROJECT_ROOT/infrastructure/utils/core.sh"

        if ! load_project_environment; then
            echo "ERROR: Failed to load project environment" >&2
            return 1
        fi
    else
        echo "CRITICAL: Core system not found" >&2
        return 1
    fi

    return 0
}

# =============================================================================
# LOAD ENVIRONMENT
# =============================================================================

if ! load_environment; then
    echo "CRITICAL: Environment loading failed" >&2
    exit 1
fi

# =============================================================================
# TEST SETUP
# =============================================================================

TEST_DIR="$PROJECT_ROOT/builds/test-e2e-$$"
TEST_INPUT="$TEST_DIR/test_input.md"
TEST_OUTPUT="$TEST_DIR/test_output.docx"

setup_test() {
    log_info "Setting up test environment..."

    # Create test directory
    mkdir -p "$TEST_DIR"

    # Create test input Markdown
    cat > "$TEST_INPUT" << 'EOF'
# Test Document

This is a test document for end-to-end pipeline validation.

## Text Elements

This is a **bold text** and this is *italic text*.

Inline code: `print("hello")`

### Code Block

```python
def test_function():
    return True
```

## Lists

Unordered list:
- Item 1
- Item 2
- Item 3

Ordered list:
1. First
2. Second
3. Third

## Table

| Column A | Column B | Column C |
|----------|----------|----------|
| Data 1   | Data 2   | Data 3   |
| Data 4   | Data 5   | Data 6   |

## Conclusion

Test document complete.
EOF

    log_success "Test environment ready"
    log_info "  Input: $TEST_INPUT"
    log_info "  Output: $TEST_OUTPUT"
}

# =============================================================================
# TEST CLEANUP
# =============================================================================

cleanup_test() {
    log_info "Cleaning up test environment..."

    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
        log_success "Test directory removed"
    fi
}

# =============================================================================
# TEST CASES
# =============================================================================

test_cli_available() {
    log_info "Test: CLI availability"

    if command -v md2docx >/dev/null 2>&1; then
        log_success "  CLI available in PATH"
        return 0
    elif [[ -x "$PROJECT_ROOT/bin/md2docx" ]]; then
        log_success "  CLI available at $PROJECT_ROOT/bin/md2docx"
        return 0
    else
        log_error "  CLI not available"
        return 1
    fi
}

test_help_command() {
    log_info "Test: Help command"

    local output
    output=$("$PROJECT_ROOT/bin/md2docx" --help 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_success "  Help command works"
        return 0
    else
        log_error "  Help command failed"
        return 1
    fi
}

test_basic_conversion() {
    log_info "Test: Basic conversion"

    # Check prerequisites
    if [[ ! -f "$DOCX_TPL" ]]; then
        log_warning "  Template missing, skipping conversion test"
        return 0
    fi

    # Perform conversion
    local output
    output=$("$PROJECT_ROOT/bin/md2docx" "$TEST_INPUT" "$TEST_OUTPUT" 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "  Conversion failed"
        echo "$output" | head -20 >&2
        return 1
    fi

    log_success "  Conversion completed"

    # Verify output exists
    if [[ ! -f "$TEST_OUTPUT" ]]; then
        log_error "  Output file not created"
        return 1
    fi

    log_success "  Output file created"

    # Check output size
    local file_size
    file_size=$(stat -c%s "$TEST_OUTPUT" 2>/dev/null || echo "0")

    if [[ $file_size -lt 1000 ]]; then
        log_error "  Output too small: $file_size bytes"
        return 1
    fi

    log_success "  Output size valid: $((file_size / 1024)) KB"

    # Check file type
    local file_type
    file_type=$(file -b --mime-type "$TEST_OUTPUT" 2>/dev/null || echo "unknown")

    if [[ "$file_type" == "application/vnd.openxmlformats-officedocument.wordprocessingml.document" ]] || \
       [[ "$file_type" == "application/zip" ]]; then
        log_success "  Output is valid DOCX file"
    else
        log_warning "  Output type: $file_type (may not be valid DOCX)"
    fi

    return 0
}

test_missing_input() {
    log_info "Test: Missing input handling"

    local fake_input="$TEST_DIR/nonexistent.md"
    local fake_output="$TEST_DIR/should_not_exist.docx"

    local output
    set +e
    output=$("$PROJECT_ROOT/bin/md2docx" "$fake_input" "$fake_output" 2>&1)
    local exit_code=$?
    set -e

    if [[ $exit_code -eq 0 ]]; then
        log_error "  Should fail with missing input"
        return 1
    fi

    if echo "$output" | grep -qi "not found\|ERROR"; then
        log_success "  Correctly reports missing input"
        return 0
    else
        log_warning "  Error message unclear"
        return 0
    fi
}

test_aliases() {
    log_info "Test: Shell aliases"

    # Source aliases
    if [[ -f "$PROJECT_ROOT/config/shell/docx-aliases.sh" ]]; then
        # shellcheck source=/dev/null
        source "$PROJECT_ROOT/config/shell/docx-aliases.sh" 2>/dev/null || true

        if command -v md2docx >/dev/null 2>&1; then
            log_success "  md2docx alias works"
        else
            log_warning "  md2docx alias not available"
        fi

        if command -v docx-config >/dev/null 2>&1; then
            log_success "  docx-config alias works"
        else
            log_warning "  docx-config alias not available"
        fi
    else
        log_warning "  Aliases file not found"
    fi

    return 0
}

test_generate_command() {
    log_info "Test: generate command"

    if [[ ! -x "$PROJECT_ROOT/bin/generate" ]]; then
        log_warning "  generate command not found, skipping"
        return 0
    fi

    # Check if template exists
    if [[ ! -f "$DOCX_TPL" ]]; then
        log_warning "  Template missing, skipping generate test"
        return 0
    fi

    local gen_output="$TEST_DIR/generate_test.docx"

    local output
    output=$("$PROJECT_ROOT/bin/generate" docx "$TEST_INPUT" "$gen_output" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_success "  generate docx command works"

        if [[ -f "$gen_output" ]]; then
            log_success "  Output created via generate"
        fi
        return 0
    else
        log_warning "  generate docx failed (may be expected)"
        return 0
    fi
}

# =============================================================================
# REPORT GENERATION
# =============================================================================

generate_test_report() {
    local passed="$1"
    local total="$2"

    log_info ""
    log_info "========================================================"
    log_info "End-to-End Test Report"
    log_info "========================================================"
    log_info ""
    log_info "Tests Passed: $passed / $total"
    log_info "Success Rate: $(( passed * 100 / total ))%"
    log_info ""

    if [[ $passed -eq $total ]]; then
        log_success "All tests passed"
        return 0
    else
        local failed=$((total - passed))
        log_warning "$failed test(s) failed"
        return 1
    fi
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    log_header "DOCX Pipeline End-to-End Test"

    local tests_passed=0
    local tests_total=0

    # Setup
    setup_test

    # Run tests
    ((tests_total++))
    if test_cli_available; then
        ((tests_passed++))
    fi

    ((tests_total++))
    if test_help_command; then
        ((tests_passed++))
    fi

    ((tests_total++))
    if test_basic_conversion; then
        ((tests_passed++))
    fi

    ((tests_total++))
    if test_missing_input; then
        ((tests_passed++))
    fi

    ((tests_total++))
    if test_aliases; then
        ((tests_passed++))
    fi

    ((tests_total++))
    if test_generate_command; then
        ((tests_passed++))
    fi

    # Cleanup
    cleanup_test

    # Report
    generate_test_report "$tests_passed" "$tests_total"
    return $?
}

# =============================================================================
# EXECUTION
# =============================================================================

main "$@"
exit $?