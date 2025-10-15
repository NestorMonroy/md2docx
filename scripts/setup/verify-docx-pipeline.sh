#!/usr/bin/env bash
# scripts/setup/verify-docx-pipeline.sh
# Comprehensive verification of DOCX pipeline installation

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
        echo "CRITICAL: Core system not found at: $PROJECT_ROOT/infrastructure/utils/core.sh" >&2
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
# VERIFICATION TESTS
# =============================================================================

verify_python_environment() {
    log_info "Verifying Python environment..."

    # Check virtualenv
    if [[ ! -d "$DOCX_VENV" ]]; then
        log_error "Virtualenv not found: $DOCX_VENV"
        return 1
    fi
    log_info "  Virtualenv: OK"

    # Check Python executable
    if [[ ! -f "$DOCX_PYTHON" ]]; then
        log_error "Python executable not found: $DOCX_PYTHON"
        return 1
    fi
    log_info "  Python: OK"

    # Check Python version
    local py_version
    py_version=$("$DOCX_PYTHON" --version 2>&1 | awk '{print $2}')
    log_info "  Version: $py_version"

    return 0
}

verify_python_dependencies() {
    log_info "Verifying Python dependencies..."

    local modules=("markdown" "bs4" "docx" "yaml")
    local missing=()

    for module in "${modules[@]}"; do
        if "$DOCX_PYTHON" -c "import $module" 2>/dev/null; then
            log_info "  $module: OK"
        else
            log_error "  $module: MISSING"
            missing+=("$module")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        return 1
    fi

    return 0
}

verify_directory_structure() {
    log_info "Verifying directory structure..."

    local dirs=(
        "$DOCX_SRC_DIR"
        "$DOCX_IMG_DIR"
        "$DOCX_BUILD_DIR"
        "$DOCX_SCRIPTS_DIR"
    )

    local missing=()

    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_info "  $(basename "$dir"): OK"
        else
            log_error "  $(basename "$dir"): MISSING"
            missing+=("$dir")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing directories: ${missing[*]}"
        return 1
    fi

    return 0
}

verify_python_scripts() {
    log_info "Verifying Python scripts..."

    local scripts=(
        "__init__.py"
        "md2docx.py"
        "h2d.py"
        "map_text.py"
        "map_list.py"
        "map_tbl.py"
        "map_inline.py"
    )

    local missing=()
    local errors=()

    for script in "${scripts[@]}"; do
        local script_path="$DOCX_SCRIPTS_DIR/$script"

        if [[ ! -f "$script_path" ]]; then
            log_error "  $script: MISSING"
            missing+=("$script")
            continue
        fi

        # Skip syntax check for __init__.py
        if [[ "$script" == "__init__.py" ]]; then
            log_info "  $script: OK"
            continue
        fi

        # Check syntax
        if "$DOCX_PYTHON" -m py_compile "$script_path" 2>/dev/null; then
            log_info "  $script: OK"
        else
            log_error "  $script: SYNTAX ERROR"
            errors+=("$script")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing scripts: ${missing[*]}"
        return 1
    fi

    if [[ ${#errors[@]} -gt 0 ]]; then
        log_error "Scripts with errors: ${errors[*]}"
        return 1
    fi

    return 0
}

verify_configuration_files() {
    log_info "Verifying configuration files..."

    # Check style.yml
    if [[ -f "$DOCX_STYLE_YML" ]]; then
        log_info "  style.yml: OK"

        # Validate YAML syntax
        if "$DOCX_PYTHON" -c "import yaml; yaml.safe_load(open('$DOCX_STYLE_YML'))" 2>/dev/null; then
            log_info "    YAML syntax: OK"
        else
            log_error "    YAML syntax: ERROR"
            return 1
        fi
    else
        log_error "  style.yml: MISSING"
        return 1
    fi

    # Check template (may not exist yet)
    if [[ -f "$DOCX_TPL" ]]; then
        log_info "  Template: OK"

        local file_size
        file_size=$(stat -c%s "$DOCX_TPL" 2>/dev/null || echo "0")
        log_info "    Size: $((file_size / 1024)) KB"
    else
        log_warning "  Template: MISSING (must be created manually)"
        log_warning "    Location: $DOCX_TPL"
    fi

    return 0
}

verify_cli() {
    log_info "Verifying CLI..."

    # Check CLI exists
    if [[ ! -f "$PROJECT_ROOT/bin/md2docx" ]]; then
        log_error "  CLI: MISSING"
        return 1
    fi
    log_info "  CLI file: OK"

    # Check executable
    if [[ ! -x "$PROJECT_ROOT/bin/md2docx" ]]; then
        log_error "  Executable: NO"
        return 1
    fi
    log_info "  Executable: OK"

    # Test help command
    if "$PROJECT_ROOT/bin/md2docx" --help >/dev/null 2>&1; then
        log_info "  Help command: OK"
    else
        log_error "  Help command: FAILED"
        return 1
    fi

    return 0
}

verify_example_input() {
    log_info "Verifying example input..."

    if [[ -f "$DOCX_INPUT_MD" ]]; then
        log_info "  Example file: OK"

        local file_size
        file_size=$(stat -c%s "$DOCX_INPUT_MD" 2>/dev/null || echo "0")
        log_info "    Size: $((file_size / 1024)) KB"
    else
        log_warning "  Example file: MISSING"
        log_warning "    Location: $DOCX_INPUT_MD"
    fi

    return 0
}

perform_conversion_test() {
    log_info "Performing conversion test..."

    # Check if we have input file
    if [[ ! -f "$DOCX_INPUT_MD" ]]; then
        log_warning "No input file for test, skipping"
        return 0
    fi

    # Check if template exists
    if [[ ! -f "$DOCX_TPL" ]]; then
        log_warning "No template for test, skipping"
        return 0
    fi

    local test_output="$DOCX_BUILD_DIR/test_verification.docx"

    log_info "  Input: $DOCX_INPUT_MD"
    log_info "  Output: $test_output"

    # Perform conversion
    local output
    output=$("$PROJECT_ROOT/bin/md2docx" "$DOCX_INPUT_MD" "$test_output" 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "  Conversion: FAILED"
        echo "$output" | head -20 >&2
        return 1
    fi

    log_info "  Conversion: OK"

    # Verify output exists
    if [[ ! -f "$test_output" ]]; then
        log_error "  Output file not created"
        return 1
    fi

    # Check output size
    local output_size
    output_size=$(stat -c%s "$test_output" 2>/dev/null || echo "0")

    if [[ $output_size -lt 1000 ]]; then
        log_error "  Output too small: $output_size bytes"
        return 1
    fi

    log_info "  Output size: $((output_size / 1024)) KB"
    log_success "Conversion test passed"

    return 0
}

# =============================================================================
# GENERATE REPORT
# =============================================================================

generate_report() {
    local passed="$1"
    local total="$2"
    local warnings="$3"

    log_info ""
    log_info "========================================================"
    log_info "DOCX Pipeline Verification Report"
    log_info "========================================================"
    log_info ""
    log_info "Tests Passed: $passed / $total"
    log_info "Warnings: $warnings"
    log_info ""

    if [[ $passed -eq $total ]] && [[ $warnings -eq 0 ]]; then
        log_success "All verification tests passed"
        log_info "The DOCX pipeline is fully functional"
        return 0
    elif [[ $passed -eq $total ]]; then
        log_success "All critical tests passed"
        log_warning "Some non-critical warnings present"
        log_info "The DOCX pipeline is functional"
        return 0
    else
        log_error "Some verification tests failed"
        log_info "The DOCX pipeline may not be fully functional"
        return 1
    fi
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    log_header "DOCX Pipeline Verification"

    local tests_passed=0
    local tests_total=0
    local warnings=0

    # Test 1: Python environment
    ((tests_total++))
    if verify_python_environment; then
        ((tests_passed++))
    fi

    # Test 2: Python dependencies
    ((tests_total++))
    if verify_python_dependencies; then
        ((tests_passed++))
    fi

    # Test 3: Directory structure
    ((tests_total++))
    if verify_directory_structure; then
        ((tests_passed++))
    fi

    # Test 4: Python scripts
    ((tests_total++))
    if verify_python_scripts; then
        ((tests_passed++))
    fi

    # Test 5: Configuration files
    ((tests_total++))
    if verify_configuration_files; then
        ((tests_passed++))
    else
        ((warnings++))
    fi

    # Test 6: CLI
    ((tests_total++))
    if verify_cli; then
        ((tests_passed++))
    fi

    # Test 7: Example input (optional)
    verify_example_input || ((warnings++))

    # Test 8: Conversion test (optional)
    if perform_conversion_test; then
        log_success "Optional conversion test passed"
    else
        log_warning "Optional conversion test failed or skipped"
        ((warnings++))
    fi

    # Generate final report
    generate_report "$tests_passed" "$tests_total" "$warnings"
    return $?
}

# =============================================================================
# EXECUTION
# =============================================================================

main "$@"
exit $?