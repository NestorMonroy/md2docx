#!/usr/bin/env bash
# scripts/setup/deploy-docx-scripts.sh
# Deploy and configure CLI for DOCX pipeline (idempotent)
#
# NOTE: Due to VirtualBox shared folder limitations, this script copies
#       the CLI to a local filesystem location where permissions can be set.

set -euo pipefail

# =============================================================================
# INITIALIZATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Local CLI location (outside shared folder)
LOCAL_CLI_DIR="/usr/local/share/docx-pipeline"
LOCAL_CLI_PATH="$LOCAL_CLI_DIR/md2docx"

# Local config location (for variables.sh)
LOCAL_CONFIG_DIR="/usr/local/share/config"
LOCAL_VARIABLES_PATH="$LOCAL_CONFIG_DIR/variables.sh"

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

    # Check local CLI exists
    if [[ ! -f "$LOCAL_CLI_PATH" ]]; then
        log_debug "Local CLI not found: $LOCAL_CLI_PATH"
        return 1
    fi

    # Check local CLI is executable
    if [[ ! -x "$LOCAL_CLI_PATH" ]]; then
        log_debug "Local CLI not executable"
        return 1
    fi

    # Check variables.sh exists
    if [[ ! -f "$LOCAL_VARIABLES_PATH" ]]; then
        log_debug "Variables file not found: $LOCAL_VARIABLES_PATH"
        return 1
    fi

    # Check CLI can run help command
    if ! bash "$LOCAL_CLI_PATH" --help >/dev/null 2>&1; then
        log_debug "CLI help command failed"
        return 1
    fi

    # Check symlink exists
    if [[ ! -L "/usr/local/bin/md2docx" ]]; then
        log_debug "Symlink not found"
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
# STEP 2: COPY CLI TO LOCAL FILESYSTEM
# =============================================================================

copy_cli_to_local() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Copying CLI to local filesystem"

    local source_cli="$PROJECT_ROOT/bin/md2docx"

    # Check if already copied and up-to-date
    if [[ -f "$LOCAL_CLI_PATH" ]]; then
        # Compare checksums
        local source_sum dest_sum
        source_sum=$(md5sum "$source_cli" 2>/dev/null | awk '{print $1}' || echo "")
        dest_sum=$(md5sum "$LOCAL_CLI_PATH" 2>/dev/null | awk '{print $1}' || echo "")

        if [[ -n "$source_sum" ]] && [[ "$source_sum" == "$dest_sum" ]]; then
            log_info "CLI already copied and up-to-date (idempotent)"
            return 0
        else
            log_info "CLI source has changed, updating local copy..."
        fi
    fi

    log_info "Copying CLI from shared folder to local filesystem..."
    log_info "  From: $source_cli"
    log_info "  To:   $LOCAL_CLI_PATH"
    log_info ""
    log_info "NOTE: This avoids VirtualBox shared folder permission limitations"

    # Create local directory if it doesn't exist
    if [[ ! -d "$LOCAL_CLI_DIR" ]]; then
        if ! mkdir -p "$LOCAL_CLI_DIR"; then
            log_error "Failed to create directory: $LOCAL_CLI_DIR"
            return 1
        fi
        log_debug "Created directory: $LOCAL_CLI_DIR"
    fi

    # Copy the file
    if ! cp "$source_cli" "$LOCAL_CLI_PATH"; then
        log_error "Failed to copy CLI to local filesystem"
        return 1
    fi

    log_success "CLI copied to local filesystem"
    return 0
}

# =============================================================================
# STEP 2.5: COPY CONFIGURATION FILE (NEW!)
# =============================================================================

copy_config_file() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Copying configuration file"

    local source_config="$PROJECT_ROOT/config/variables.sh"

    # Verify source exists
    if [[ ! -f "$source_config" ]]; then
        log_error "Configuration file not found: $source_config"
        return 1
    fi

    # Check if already copied and up-to-date
    if [[ -f "$LOCAL_VARIABLES_PATH" ]]; then
        local source_sum dest_sum
        source_sum=$(md5sum "$source_config" 2>/dev/null | awk '{print $1}' || echo "")
        dest_sum=$(md5sum "$LOCAL_VARIABLES_PATH" 2>/dev/null | awk '{print $1}' || echo "")

        if [[ -n "$source_sum" ]] && [[ "$source_sum" == "$dest_sum" ]]; then
            log_info "Configuration already copied and up-to-date (idempotent)"
            return 0
        else
            log_info "Configuration has changed, updating local copy..."
        fi
    fi

    log_info "Copying configuration from shared folder to local filesystem..."
    log_info "  From: $source_config"
    log_info "  To:   $LOCAL_VARIABLES_PATH"

    # Create config directory if it doesn't exist
    if [[ ! -d "$LOCAL_CONFIG_DIR" ]]; then
        if ! mkdir -p "$LOCAL_CONFIG_DIR"; then
            log_error "Failed to create directory: $LOCAL_CONFIG_DIR"
            return 1
        fi
        log_debug "Created directory: $LOCAL_CONFIG_DIR"
    fi

    # Copy the file
    if ! cp "$source_config" "$LOCAL_VARIABLES_PATH"; then
        log_error "Failed to copy configuration file"
        return 1
    fi

    log_success "Configuration file copied"
    log_info "  Location: $LOCAL_VARIABLES_PATH"

    return 0
}

# =============================================================================
# STEP 3: MAKE LOCAL CLI EXECUTABLE
# =============================================================================

make_cli_executable() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Making CLI executable"

    # Check current permissions
    local perms
    perms=$(stat -c%a "$LOCAL_CLI_PATH" 2>/dev/null || stat -f%Lp "$LOCAL_CLI_PATH" 2>/dev/null || echo "000")
    log_debug "Current permissions: $perms"

    # If already executable, we're done
    if [[ -x "$LOCAL_CLI_PATH" ]]; then
        log_info "CLI already executable (idempotent)"
        log_info "  Permissions: $perms"
        return 0
    fi

    log_info "Setting executable permissions on local copy..."

    # Set permissions (this should work on local filesystem)
    if ! chmod 755 "$LOCAL_CLI_PATH"; then
        log_error "Failed to make CLI executable"
        log_error "  File: $LOCAL_CLI_PATH"
        return 1
    fi

    # Verify it worked
    if [[ ! -x "$LOCAL_CLI_PATH" ]]; then
        log_error "CLI still not executable after chmod"
        return 1
    fi

    log_success "CLI is now executable"

    # Show final permissions
    perms=$(stat -c%a "$LOCAL_CLI_PATH" 2>/dev/null || stat -f%Lp "$LOCAL_CLI_PATH" 2>/dev/null || echo "unknown")
    log_info "  Permissions: $perms"
    log_info "  Owner: $(stat -c%U:%G "$LOCAL_CLI_PATH" 2>/dev/null || stat -f%Su:%Sg "$LOCAL_CLI_PATH" 2>/dev/null || echo "unknown")"

    return 0
}

# =============================================================================
# STEP 4: VERIFY CLI SYNTAX
# =============================================================================

verify_cli_syntax() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Verifying CLI syntax"

    log_info "Checking Bash syntax..."

    local syntax_check
    if syntax_check=$(bash -n "$LOCAL_CLI_PATH" 2>&1); then
        log_success "CLI syntax is valid"
        return 0
    else
        log_error "CLI has syntax errors:"
        echo "$syntax_check" | head -20 >&2
        return 1
    fi
}

# =============================================================================
# STEP 5: CONFIGURE SHELL ALIASES
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
# STEP 6: CREATE SYMLINK
# =============================================================================

create_symlink() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Creating system-wide symlink"

    local symlink_path="/usr/local/bin/md2docx"

    # Check if symlink already exists and is correct
    if [[ -L "$symlink_path" ]]; then
        local link_target
        link_target=$(readlink -f "$symlink_path" 2>/dev/null || readlink "$symlink_path" 2>/dev/null || echo "")

        if [[ "$link_target" == "$LOCAL_CLI_PATH" ]]; then
            log_info "Symlink already exists and is correct (idempotent)"
            return 0
        else
            log_info "Symlink exists but points to wrong location: $link_target"
            log_info "Removing old symlink..."
            if ! rm -f "$symlink_path" 2>/dev/null; then
                log_error "Failed to remove old symlink"
                return 1
            fi
        fi
    fi

    # Create new symlink to LOCAL copy (not shared folder)
    log_info "Creating symlink: $symlink_path -> $LOCAL_CLI_PATH"

    if ! ln -s "$LOCAL_CLI_PATH" "$symlink_path" 2>/dev/null; then
        log_error "Failed to create symlink"
        return 1
    fi

    log_success "Symlink created"
    log_info "  md2docx is now available system-wide"

    return 0
}

# =============================================================================
# STEP 7: TEST CLI
# =============================================================================

test_cli() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Testing CLI"

    log_info "Testing help command..."

    # Test the local copy
    local help_output
    local exit_code

    help_output=$("$LOCAL_CLI_PATH" --help 2>&1)
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "CLI help command failed with exit code: $exit_code"
        log_error "Output:"
        echo "$help_output" | head -20 >&2
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

    # Test via symlink
    log_info "Testing via symlink..."
    if command -v md2docx >/dev/null 2>&1; then
        if md2docx --help >/dev/null 2>&1; then
            log_success "Symlink works correctly"
        else
            log_warning "Symlink exists but command failed"
        fi
    fi

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
            log_info "  Source: $PROJECT_ROOT/bin/md2docx"
            log_info "  Local copy: $LOCAL_CLI_PATH"
            log_info "  Config: $LOCAL_VARIABLES_PATH"
            log_info "  Symlink: /usr/local/bin/md2docx"

            return 0
        else
            log_warning "CLI marked as deployed but verification failed"
            log_info "Redeploying..."
        fi
    else
        log_info "DOCX CLI not deployed, proceeding with deployment"
    fi

    # Execute deployment steps (UPDATED: now 8 steps instead of 7)
    if ! verify_cli_source 1 8; then
        log_error "Failed at step 1: Source verification"
        return 1
    fi

    if ! copy_cli_to_local 2 8; then
        log_error "Failed at step 2: Copy CLI to local filesystem"
        return 1
    fi

    if ! copy_config_file 3 8; then
        log_error "Failed at step 3: Copy configuration file"
        return 1
    fi

    if ! make_cli_executable 4 8; then
        log_error "Failed at step 4: Make executable"
        return 1
    fi

    if ! verify_cli_syntax 5 8; then
        log_error "Failed at step 5: Syntax verification"
        return 1
    fi

    if ! configure_shell_aliases 6 8; then
        log_error "Failed at step 6: Aliases configuration"
        return 1
    fi

    if ! create_symlink 7 8; then
        log_error "Failed at step 7: Symlink creation"
        return 1
    fi

    if ! test_cli 8 8; then
        log_error "Failed at step 8: CLI testing"
        return 1
    fi

    # Final verification
    if verify_cli_deployed; then
        log_success "DOCX CLI deployment completed successfully"
        mark_installation_state "docx-cli"

        log_info "Deployment details:"
        log_info "  Source: $PROJECT_ROOT/bin/md2docx"
        log_info "  Local copy: $LOCAL_CLI_PATH"
        log_info "  Config: $LOCAL_VARIABLES_PATH"
        log_info "  Symlink: /usr/local/bin/md2docx"
        log_info "  Aliases: $PROJECT_ROOT/config/shell/docx-aliases.sh"

        log_info "Available commands:"
        log_info "  md2docx input.md output.docx"
        log_info "  md2docx --help"
        log_info "  md2docx-quick (uses defaults)"
        log_info "  docx-config (show configuration)"

        log_info "Technical note:"
        log_info "  CLI and config are copied to local filesystem to avoid"
        log_info "  VirtualBox shared folder permission issues"

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