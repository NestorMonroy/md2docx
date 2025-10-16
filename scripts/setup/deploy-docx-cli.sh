#!/usr/bin/env bash
# scripts/setup/deploy-docx-cli.sh
# Deploy and configure CLI for DOCX pipeline (idempotent)

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

    # Check if DOCX scripts are deployed
    if ! is_component_functional "docx-scripts"; then
        log_error "DOCX scripts not deployed"
        log_info "ACCION REQUERIDA: Run deployment script:"
        log_info "  sudo bash scripts/setup/deploy-docx-scripts.sh"
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

verify_cli_deployed() {
    log_debug "Verifying CLI deployment"

    # Check wrapper exists in /usr/local/bin
    if [[ ! -f "/usr/local/bin/md2docx" ]]; then
        log_debug "Wrapper not found in /usr/local/bin"
        return 1
    fi

    # Check wrapper is executable
    if [[ ! -x "/usr/local/bin/md2docx" ]]; then
        log_debug "Wrapper not executable"
        return 1
    fi

    # Check original CLI exists
    if [[ ! -f "$PROJECT_ROOT/bin/md2docx" ]]; then
        log_debug "Original CLI not found"
        return 1
    fi

    # Check aliases file exists
    if [[ ! -f "$PROJECT_ROOT/config/shell/docx-aliases.sh" ]]; then
        log_debug "Aliases file not found"
        return 1
    fi

    log_debug "CLI deployment verified"
    return 0
}

# =============================================================================
# STEP 1: VERIFY CLI SOURCE
# =============================================================================

verify_cli_source() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Verifying CLI source"

    if [[ ! -f "$PROJECT_ROOT/bin/md2docx" ]]; then
        log_error "CLI source not found: $PROJECT_ROOT/bin/md2docx"
        log_info "ACCION REQUERIDA: CLI script must be present in repository"
        return 1
    fi

    # Check file size is reasonable
    local file_size
    file_size=$(stat -c%s "$PROJECT_ROOT/bin/md2docx" 2>/dev/null || stat -f%z "$PROJECT_ROOT/bin/md2docx" 2>/dev/null || echo "0")

    if [[ "$file_size" -lt 100 ]]; then
        log_error "CLI file is too small (possibly corrupted): $file_size bytes"
        return 1
    fi

    log_success "CLI source verified"
    log_info "  Location: $PROJECT_ROOT/bin/md2docx"
    log_info "  Size: $((file_size / 1024)) KB"

    return 0
}

# =============================================================================
# STEP 2: VERIFY CLI SYNTAX
# =============================================================================

verify_cli_syntax() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Verifying CLI syntax"

    log_info "Checking Bash syntax..."

    local syntax_check
    if syntax_check=$(bash -n "$PROJECT_ROOT/bin/md2docx" 2>&1); then
        log_success "CLI syntax is valid"
        return 0
    else
        log_error "CLI has syntax errors:"
        echo "$syntax_check" | head -20 >&2
        return 1
    fi
}

# =============================================================================
# STEP 3: CREATE WRAPPER SCRIPT
# =============================================================================

create_wrapper_script() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Creating wrapper script"

    local wrapper_path="/usr/local/bin/md2docx"

    # Check if wrapper already exists and is correct
    if [[ -f "$wrapper_path" ]] && [[ -x "$wrapper_path" ]]; then
        # Check if it's already a valid wrapper
        if grep -q "PROJECT_ROOT=\"$PROJECT_ROOT\"" "$wrapper_path" 2>/dev/null; then
            log_info "Wrapper already exists and is correct (idempotent)"
            return 0
        else
            log_info "Wrapper exists but needs update, recreating..."
        fi
    fi

    log_info "Creating wrapper script..."
    log_info "  Wrapper: $wrapper_path"
    log_info "  Points to: $PROJECT_ROOT/bin/md2docx"

    # Create wrapper script that sets PROJECT_ROOT correctly
    cat > "$wrapper_path" << EOF
#!/usr/bin/env bash
# Wrapper for md2docx CLI
# Auto-generated by deploy-docx-cli.sh
# This wrapper ensures PROJECT_ROOT is set correctly

# Set PROJECT_ROOT to the correct location
export PROJECT_ROOT="$PROJECT_ROOT"

# Execute the actual CLI script using bash
exec bash "$PROJECT_ROOT/bin/md2docx" "\$@"
EOF

    if [[ ! -f "$wrapper_path" ]]; then
        log_error "Failed to create wrapper script"
        return 1
    fi

    # Make wrapper executable
    if ! chmod 755 "$wrapper_path" 2>/dev/null; then
        log_error "Failed to make wrapper executable"
        return 1
    fi

    log_success "Wrapper script created"
    log_info "  Location: $wrapper_path"
    log_info "  Permissions: 755"

    return 0
}

# =============================================================================
# STEP 4: CONFIGURE SHELL ALIASES
# =============================================================================

configure_shell_aliases() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Configuring shell aliases"

    local aliases_file="$PROJECT_ROOT/config/shell/docx-aliases.sh"

    # Check aliases file exists
    if [[ ! -f "$aliases_file" ]]; then
        log_error "Aliases file not found: $aliases_file"
        log_info "ACCION REQUERIDA: Create aliases file"
        return 1
    fi

    # Verify aliases file syntax
    log_info "Verifying aliases syntax..."
    local alias_syntax
    if alias_syntax=$(bash -n "$aliases_file" 2>&1); then
        log_debug "Aliases syntax valid"
    else
        log_error "Aliases file has syntax errors:"
        echo "$alias_syntax" | head -20 >&2
        return 1
    fi

    # Configure for vagrant user
    local vagrant_bashrc="/home/vagrant/.bashrc"
    local source_line="source $PROJECT_ROOT/config/shell/docx-aliases.sh"

    if [[ -f "$vagrant_bashrc" ]]; then
        if grep -qF "docx-aliases.sh" "$vagrant_bashrc"; then
            log_info "Aliases already configured in .bashrc (idempotent)"
        else
            log_info "Adding aliases to .bashrc..."

            if ! {
                echo ""
                echo "# DOCX Pipeline Aliases (added by deploy-docx-cli.sh)"
                echo "$source_line"
            } >> "$vagrant_bashrc"; then
                log_error "Failed to add aliases to .bashrc"
                return 1
            fi

            log_success "Aliases added to .bashrc"
        fi
    else
        log_warning ".bashrc not found for vagrant user"
    fi

    log_success "Shell aliases configured"
    return 0
}

# =============================================================================
# STEP 5: TEST CLI
# =============================================================================

test_cli() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Testing CLI"

    local wrapper_path="/usr/local/bin/md2docx"

    log_info "Testing wrapper script..."

    # Test help command
    local help_output
    local exit_code

    help_output=$("$wrapper_path" --help 2>&1)
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "CLI help command failed with exit code: $exit_code"
        log_error "Output:"
        echo "$help_output" | head -30 >&2

        # Diagnostic information
        log_info "Diagnostic info:"
        log_info "  Wrapper: $wrapper_path"
        log_info "  Exists: $([ -f "$wrapper_path" ] && echo "yes" || echo "no")"
        log_info "  Executable: $([ -x "$wrapper_path" ] && echo "yes" || echo "no")"
        log_info "  Original CLI: $PROJECT_ROOT/bin/md2docx"
        log_info "  Original exists: $([ -f "$PROJECT_ROOT/bin/md2docx" ] && echo "yes" || echo "no")"

        return 1
    fi

    # Check for expected content
    if ! echo "$help_output" | grep -q "Usage:"; then
        log_error "CLI help output seems incorrect"
        log_info "Expected 'Usage:' in output, got:"
        echo "$help_output" | head -10 >&2
        return 1
    fi

    log_success "CLI test passed"
    log_info "  Wrapper works correctly"

    return 0
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    log_header "DOCX CLI Deployment"

    # Check if already deployed
    if is_component_functional "docx-cli"; then
        if verify_cli_deployed; then
            log_success "DOCX CLI already deployed and verified"
            log_info "Skipping deployment (idempotence)"

            log_info "CLI status:"
            log_info "  Wrapper: /usr/local/bin/md2docx"
            log_info "  Original: $PROJECT_ROOT/bin/md2docx"
            log_info "  Aliases: loaded in .bashrc"

            return 0
        else
            log_warning "CLI marked as deployed but verification failed"
            log_info "Redeploying..."
        fi
    else
        log_info "DOCX CLI not deployed, proceeding with deployment"
    fi

    # Execute deployment steps (5 steps now)
    if ! verify_cli_source 1 5; then
        log_error "Failed at step 1: Source verification"
        return 1
    fi

    if ! verify_cli_syntax 2 5; then
        log_error "Failed at step 2: Syntax verification"
        return 1
    fi

    if ! create_wrapper_script 3 5; then
        log_error "Failed at step 3: Wrapper creation"
        return 1
    fi

    if ! configure_shell_aliases 4 5; then
        log_error "Failed at step 4: Aliases configuration"
        return 1
    fi

    if ! test_cli 5 5; then
        log_error "Failed at step 5: CLI testing"
        return 1
    fi

    # Final verification
    if verify_cli_deployed; then
        log_success "DOCX CLI deployment completed successfully"
        mark_installation_state "docx-cli"

        log_info "Deployment details:"
        log_info "  Wrapper: /usr/local/bin/md2docx"
        log_info "  Original CLI: $PROJECT_ROOT/bin/md2docx"
        log_info "  Aliases: $PROJECT_ROOT/config/shell/docx-aliases.sh"

        log_info "Available commands:"
        log_info "  md2docx INPUT.md OUTPUT.docx"
        log_info "  md2docx --help"
        log_info "  md2docx-quick (uses defaults)"
        log_info "  docx-config (show configuration)"

        log_info "How it works:"
        log_info "  The wrapper sets PROJECT_ROOT=$PROJECT_ROOT"
        log_info "  Then executes the original CLI script"

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