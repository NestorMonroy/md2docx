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

    # Check CLI exists
    if [[ ! -f "$PROJECT_ROOT/bin/md2docx" ]]; then
        log_debug "CLI not found: $PROJECT_ROOT/bin/md2docx"
        return 1
    fi

    # Check CLI is executable
    if [[ ! -x "$PROJECT_ROOT/bin/md2docx" ]]; then
        log_debug "CLI not executable"
        return 1
    fi

    # Check CLI can run help command (using bash explicitly)
    if ! bash "$PROJECT_ROOT/bin/md2docx" --help >/dev/null 2>&1; then
        log_debug "CLI help command failed"
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
# STEP 2: MAKE CLI EXECUTABLE
# =============================================================================

make_cli_executable() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Making CLI executable"

    local cli_file="$PROJECT_ROOT/bin/md2docx"

    # Check current permissions
    local perms
    perms=$(stat -c%a "$cli_file" 2>/dev/null || stat -f%Lp "$cli_file" 2>/dev/null || echo "000")
    log_debug "Current permissions: $perms"

    # If already executable, we're done
    if [[ -x "$cli_file" ]]; then
        log_info "CLI already executable (idempotent)"
        log_info "  Permissions: $perms"
        return 0
    fi

    log_info "Setting executable permissions..."

    # Try multiple approaches to make it executable
    local made_executable=false
    local attempts=0
    local max_attempts=3

    # Approach 1: Standard chmod +x
    ((attempts++))
    log_debug "Attempt $attempts: chmod +x"
    if chmod +x "$cli_file" 2>/dev/null; then
        if [[ -x "$cli_file" ]]; then
            log_debug "chmod +x succeeded"
            made_executable=true
        fi
    fi

    # Approach 2: Explicit mode 755
    if [[ "$made_executable" != "true" ]]; then
        ((attempts++))
        log_debug "Attempt $attempts: chmod 755"
        if chmod 755 "$cli_file" 2>/dev/null; then
            if [[ -x "$cli_file" ]]; then
                log_debug "chmod 755 succeeded"
                made_executable=true
            fi
        fi
    fi

    # Approach 3: Individual permission bits
    if [[ "$made_executable" != "true" ]]; then
        ((attempts++))
        log_debug "Attempt $attempts: chmod u+x,g+x,o+x"
        if chmod u+x,g+x,o+x "$cli_file" 2>/dev/null; then
            if [[ -x "$cli_file" ]]; then
                log_debug "chmod u+x,g+x,o+x succeeded"
                made_executable=true
            fi
        fi
    fi

    # Verify it worked
    if [[ ! -x "$cli_file" ]]; then
        log_error "Failed to make CLI executable after $attempts attempts"
        log_error "File details:"
        log_error "  Location: $cli_file"
        log_error "  Permissions: $(ls -l "$cli_file" 2>/dev/null || echo "unknown")"
        log_error "  Owner: $(stat -c%U:%G "$cli_file" 2>/dev/null || stat -f%Su:%Sg "$cli_file" 2>/dev/null || echo "unknown")"
        log_info "ACCION REQUERIDA: Manually run: chmod +x $cli_file"
        return 1
    fi

    log_success "CLI is now executable"

    # Show final permissions
    perms=$(stat -c%a "$cli_file" 2>/dev/null || stat -f%Lp "$cli_file" 2>/dev/null || echo "unknown")
    log_info "  Permissions: $perms"

    return 0
}

# =============================================================================
# STEP 3: VERIFY CLI SYNTAX
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
# STEP 5: CREATE SYMLINK
# =============================================================================

create_symlink() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Creating system-wide symlink (optional)"

    local symlink_path="/usr/local/bin/md2docx"

    # Check if symlink already exists and is correct
    if [[ -L "$symlink_path" ]]; then
        local link_target
        link_target=$(readlink -f "$symlink_path" 2>/dev/null || readlink "$symlink_path" 2>/dev/null || echo "")

        local expected_target
        expected_target=$(readlink -f "$PROJECT_ROOT/bin/md2docx" 2>/dev/null || echo "$PROJECT_ROOT/bin/md2docx")

        if [[ "$link_target" == "$expected_target" ]]; then
            log_info "Symlink already exists and is correct (idempotent)"
            return 0
        else
            log_warning "Symlink exists but points to wrong location: $link_target"
            log_info "Removing old symlink..."
            if ! rm -f "$symlink_path" 2>/dev/null; then
                log_error "Failed to remove old symlink"
                return 1
            fi
        fi
    fi

    # Create new symlink
    log_info "Creating symlink: $symlink_path -> $PROJECT_ROOT/bin/md2docx"

    if ln -s "$PROJECT_ROOT/bin/md2docx" "$symlink_path" 2>/dev/null; then
        log_success "Symlink created"
        log_info "  md2docx is now available system-wide"
    else
        log_warning "Failed to create symlink (not critical)"
        log_info "CLI can still be used via: $PROJECT_ROOT/bin/md2docx"
        log_info "Or via: bash /vagrant/bin/md2docx"
    fi

    return 0
}

# =============================================================================
# STEP 6: TEST CLI
# =============================================================================

test_cli() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Testing CLI"

    local cli_file="$PROJECT_ROOT/bin/md2docx"

    # Pre-test: verify file is still executable
    if [[ ! -x "$cli_file" ]]; then
        log_warning "CLI lost executable permissions before test"
        log_info "Attempting to restore permissions..."

        chmod +x "$cli_file" 2>/dev/null || chmod 755 "$cli_file" 2>/dev/null

        if [[ ! -x "$cli_file" ]]; then
            log_error "Cannot restore executable permissions"
            log_error "File may be on a filesystem that doesn't support execute permissions"
            log_info "Will test using 'bash' explicitly instead"
        fi
    fi

    log_info "Testing help command..."

    # Use bash explicitly to run the script (works even without +x in shared folders)
    local help_output
    local exit_code

    help_output=$(bash "$cli_file" --help 2>&1)
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "CLI help command failed with exit code: $exit_code"
        log_error "Output:"
        echo "$help_output" | head -20 >&2

        # Diagnostic information
        log_info "Diagnostic info:"
        log_info "  File: $cli_file"
        log_info "  Exists: $([ -f "$cli_file" ] && echo "yes" || echo "no")"
        log_info "  Readable: $([ -r "$cli_file" ] && echo "yes" || echo "no")"
        log_info "  Executable: $([ -x "$cli_file" ] && echo "yes" || echo "no")"
        log_info "  Permissions: $(ls -l "$cli_file" 2>/dev/null || echo "unknown")"

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
    log_info "  Tested with: bash $cli_file --help"

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
            log_info "  Location: $PROJECT_ROOT/bin/md2docx"
            log_info "  Symlink: /usr/local/bin/md2docx"
            log_info "  Aliases: loaded in .bashrc"

            return 0
        else
            log_warning "CLI marked as deployed but verification failed"
            log_info "Redeploying..."
        fi
    else
        log_info "DOCX CLI not deployed, proceeding with deployment"
    fi

    # Execute deployment steps
    if ! verify_cli_source 1 6; then
        log_error "Failed at step 1: Source verification"
        return 1
    fi

    if ! make_cli_executable 2 6; then
        log_error "Failed at step 2: Make executable"
        return 1
    fi

    if ! verify_cli_syntax 3 6; then
        log_error "Failed at step 3: Syntax verification"
        return 1
    fi

    if ! configure_shell_aliases 4 6; then
        log_error "Failed at step 4: Aliases configuration"
        return 1
    fi

    if ! create_symlink 5 6; then
        log_warning "Step 5: Symlink creation had issues (non-critical)"
        # Don't fail on symlink issues
    fi

    if ! test_cli 6 6; then
        log_error "Failed at step 6: CLI testing"
        return 1
    fi

    # Final verification
    if verify_cli_deployed; then
        log_success "DOCX CLI deployment completed successfully"
        mark_installation_state "docx-cli"

        log_info "Deployment details:"
        log_info "  CLI: $PROJECT_ROOT/bin/md2docx"
        log_info "  Aliases: $PROJECT_ROOT/config/shell/docx-aliases.sh"
        log_info "  Symlink: /usr/local/bin/md2docx"

        log_info "Available commands:"
        log_info "  md2docx INPUT.md OUTPUT.docx"
        log_info "  bash /vagrant/bin/md2docx --help"
        log_info "  md2docx-quick (uses defaults)"
        log_info "  docx-config (show configuration)"

        log_info "Note: If 'md2docx' alone doesn't work, use:"
        log_info "  bash /vagrant/bin/md2docx"

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
exit $