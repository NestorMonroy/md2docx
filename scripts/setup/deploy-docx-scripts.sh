#!/usr/bin/env bash
# scripts/setup/deploy-docx-scripts.sh
# Deploy Python scripts for DOCX pipeline (idempotent)

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
# VALIDATE PREREQUISITES
# =============================================================================

validate_prerequisites() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        return 1
    fi

    log_debug "Prerequisites validation started"

    # Check if DOCX stack is installed
    if ! is_component_functional "docx-stack"; then
        log_error "DOCX stack not installed"
        log_error "Run: sudo bash scripts/installation/install-docx-stack.sh"
        return 1
    fi

    # Check if scripts directory exists in project
    if [[ ! -d "$PROJECT_ROOT/scripts/mdx" ]]; then
        log_error "Source scripts directory not found: $PROJECT_ROOT/scripts/mdx"
        return 1
    fi

    log_debug "Prerequisites validated"
    return 0
}

# =============================================================================
# LOAD ENVIRONMENT AND VALIDATE
# =============================================================================

if ! load_environment; then
    echo "CRITICAL: Environment loading failed" >&2
    exit 1
fi

if ! validate_prerequisites; then
    log_error "Prerequisites validation failed"
    exit 1
fi

# =============================================================================
# VERIFICATION FUNCTION
# =============================================================================

verify_scripts_deployed() {
    log_debug "Verifying scripts deployment"

    local required_scripts=(
        "__init__.py"
        "md2docx.py"
        "h2d.py"
        "map_text.py"
        "map_list.py"
        "map_tbl.py"
        "map_inline.py"
    )

    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$DOCX_SCRIPTS_DIR/$script" ]]; then
            log_debug "Script missing: $script"
            return 1
        fi
    done

    # Verify Python syntax
    for script in "${required_scripts[@]}"; do
        if [[ "$script" == "__init__.py" ]]; then
            continue
        fi

        if ! "$DOCX_PYTHON" -m py_compile "$DOCX_SCRIPTS_DIR/$script" 2>/dev/null; then
            log_debug "Script has syntax errors: $script"
            return 1
        fi
    done

    log_debug "Scripts deployment verified"
    return 0
}

# =============================================================================
# STEP 1: CREATE TARGET DIRECTORY
# =============================================================================

create_target_directory() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Creating target directory"

    if [[ -d "$DOCX_SCRIPTS_DIR" ]]; then
        log_info "Target directory already exists: $DOCX_SCRIPTS_DIR"
        return 0
    fi

    log_info "Creating directory: $DOCX_SCRIPTS_DIR"

    if ! mkdir -p "$DOCX_SCRIPTS_DIR"; then
        log_error "Failed to create directory: $DOCX_SCRIPTS_DIR"
        return 1
    fi

    log_success "Target directory created"
    return 0
}

# =============================================================================
# STEP 2: VERIFY SOURCE SCRIPTS
# =============================================================================

verify_source_scripts() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Verifying source scripts"

    local required_scripts=(
        "__init__.py"
        "md2docx.py"
        "h2d.py"
        "map_text.py"
        "map_list.py"
        "map_tbl.py"
        "map_inline.py"
    )

    local missing=()

    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/scripts/mdx/$script" ]]; then
            missing+=("$script")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing source scripts: ${missing[*]}"
        log_error "Location: $PROJECT_ROOT/scripts/mdx/"
        return 1
    fi

    log_success "All source scripts found"
    log_info "  Location: $PROJECT_ROOT/scripts/mdx/"

    return 0
}

# =============================================================================
# STEP 3: COPY SCRIPTS
# =============================================================================

copy_scripts() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Copying scripts to target"

    local scripts=(
        "__init__.py"
        "md2docx.py"
        "h2d.py"
        "map_text.py"
        "map_list.py"
        "map_tbl.py"
        "map_inline.py"
    )

    local copied=0
    local skipped=0
    local failed=0

    for script in "${scripts[@]}"; do
        local source="$PROJECT_ROOT/scripts/mdx/$script"
        local target="$DOCX_SCRIPTS_DIR/$script"

        # Check if target exists and is identical
        if [[ -f "$target" ]]; then
            if cmp -s "$source" "$target"; then
                log_debug "Already up to date: $script"
                ((skipped++))
                continue
            else
                log_info "Updating: $script"
            fi
        else
            log_info "Copying: $script"
        fi

        if cp "$source" "$target"; then
            ((copied++))
        else
            log_error "Failed to copy: $script"
            ((failed++))
        fi
    done

    log_info "Copy summary:"
    log_info "  Copied: $copied"
    log_info "  Skipped: $skipped"

    if [[ $failed -gt 0 ]]; then
        log_info "  Failed: $failed"
        return 1
    fi

    log_success "Scripts copied to target"
    return 0
}

# =============================================================================
# STEP 4: SET PERMISSIONS
# =============================================================================

set_permissions() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Setting permissions"

    log_info "Setting directory permissions (755)..."
    if ! chmod 755 "$DOCX_SCRIPTS_DIR"; then
        log_error "Failed to set directory permissions"
        return 1
    fi

    log_info "Setting file permissions (644)..."
    if ! chmod 644 "$DOCX_SCRIPTS_DIR"/*.py; then
        log_error "Failed to set file permissions"
        return 1
    fi

    # Make main script executable
    log_info "Making md2docx.py executable..."
    if ! chmod +x "$DOCX_SCRIPTS_DIR/md2docx.py"; then
        log_warning "Failed to make md2docx.py executable (not critical)"
    fi

    log_success "Permissions configured"
    return 0
}

# =============================================================================
# STEP 5: VALIDATE PYTHON SYNTAX
# =============================================================================

validate_python_syntax() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Validating Python syntax"

    local scripts=(
        "md2docx.py"
        "h2d.py"
        "map_text.py"
        "map_list.py"
        "map_tbl.py"
        "map_inline.py"
    )

    local errors=0

    for script in "${scripts[@]}"; do
        log_info "Checking: $script"

        local output
        output=$("$DOCX_PYTHON" -m py_compile "$DOCX_SCRIPTS_DIR/$script" 2>&1)
        local exit_code=$?

        if [[ $exit_code -ne 0 ]]; then
            log_error "Syntax error in: $script"
            echo "$output" | head -10 >&2
            ((errors++))
        else
            log_debug "  Syntax OK"
        fi
    done

    if [[ $errors -gt 0 ]]; then
        log_error "Found $errors script(s) with syntax errors"
        return 1
    fi

    log_success "All scripts have valid syntax"
    return 0
}

# =============================================================================
# STEP 6: TEST IMPORTS
# =============================================================================

test_imports() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Testing module imports"

    # Test importing the package
    log_info "Testing package import..."

    local test_script="
import sys
sys.path.insert(0, '$PROJECT_ROOT/scripts')

try:
    from mdx import md2docx, h2d
    from mdx import map_text, map_list, map_tbl, map_inline
    print('SUCCESS')
except ImportError as e:
    print(f'IMPORT_ERROR: {e}')
    sys.exit(1)
except Exception as e:
    print(f'ERROR: {e}')
    sys.exit(1)
"

    local output
    output=$("$DOCX_PYTHON" -c "$test_script" 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "Import test failed"
        echo "$output" >&2
        return 1
    fi

    if ! echo "$output" | grep -q "SUCCESS"; then
        log_error "Import test did not complete successfully"
        echo "$output" >&2
        return 1
    fi

    log_success "All modules import successfully"
    return 0
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    log_header "DOCX Scripts Deployment"

    if is_component_functional "docx-scripts"; then
        log_success "DOCX scripts already deployed"
        log_info "Skipping deployment (idempotence)"
        return 0
    fi

    log_info "DOCX scripts not deployed, proceeding with deployment"

    create_target_directory 1 6 || return 1
    verify_source_scripts 2 6 || return 1
    copy_scripts 3 6 || return 1
    set_permissions 4 6 || return 1
    validate_python_syntax 5 6 || return 1
    test_imports 6 6 || return 1

    if verify_scripts_deployed; then
        log_success "DOCX scripts deployment verified"
        mark_installation_state "docx-scripts"

        log_info "Deployment details:"
        log_info "  Location: $DOCX_SCRIPTS_DIR"
        log_info "  Scripts deployed: 7"
        log_info "  Main script: md2docx.py"

        return 0
    else
        log_error "Verification failed after deployment"
        return 1
    fi
}

# =============================================================================
# EXECUTION
# =============================================================================

main "$@"
exit $?