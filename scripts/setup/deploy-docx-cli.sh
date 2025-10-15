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
        log_error "Run: sudo bash scripts/setup/deploy-docx-scripts.sh"
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

    # Check aliases are loaded
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
        log_error "The CLI script must be present in the repository"
        return 1
    fi

    log_success "CLI source verified"
    log_info "  Location: $PROJECT_ROOT/bin/md2docx"

    return 0
}

# =============================================================================
# STEP 2: MAKE CLI EXECUTABLE
# =============================================================================

make_cli_executable() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Making CLI executable"

    if [[ -x "$PROJECT_ROOT/bin/md2docx" ]]; then
        log_info "CLI already executable"
        return 0
    fi

    log_info "Setting executable permissions..."

    if ! chmod +x "$PROJECT_ROOT/bin/md2docx"; then
        log_error "Failed to make CLI executable"
        return 1
    fi

    log_success "CLI is now executable"
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

    local output
    output=$(bash -n "$PROJECT_ROOT/bin/md2docx" 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "CLI has syntax errors"
        echo "$output" >&2
        return 1
    fi

    log_success "CLI syntax is valid"
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

    if [[ ! -f "$aliases_file" ]]; then
        log_error "Aliases file not found: $aliases_file"
        return 1
    fi

    # Verify aliases file syntax
    log_info "Verifying aliases syntax..."
    local output
    output=$(bash -n "$aliases_file" 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "Aliases file has syntax errors"
        echo "$output" >&2
        return 1
    fi

    # Add to vagrant user's bashrc if not already present
    local vagrant_bashrc="/home/vagrant/.bashrc"
    local source_line="source $PROJECT_ROOT/config/shell/docx-aliases.sh"

    if [[ -f "$vagrant_bashrc" ]]; then
        if grep -q "docx-aliases.sh" "$vagrant_bashrc"; then
            log_info "Aliases already configured in .bashrc"
        else
            log_info "Adding aliases to .bashrc..."
            {
                echo ""
                echo "# DOCX Pipeline Aliases"
                echo "$source_line"
            } >> "$vagrant_bashrc"
            log_success "Aliases added to .bashrc"
        fi
    fi

    log_success "Shell aliases configured"
    return 0
}

# =============================================================================
# STEP 5: CREATE SYMLINK (OPTIONAL)
# =============================================================================

create_symlink() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Creating system-wide symlink (optional)"

    local symlink_path="/usr/local/bin/md2docx"

    if [[ -L "$symlink_path" ]]; then
        log_info "Symlink already exists: $symlink_path"

        # Verify it points to correct location
        local link_target
        link_target=$(readlink "$symlink_path")

        if [[ "$link_target" == "$PROJECT_ROOT/bin/md2docx" ]]; then
            log_info "Symlink points to correct location"
            return 0
        else
            log_warning "Symlink points to wrong location: $link_target"
            log_info "Removing old symlink..."
            rm -f "$symlink_path"
        fi
    fi

    log_info "Creating symlink: $symlink_path -> $PROJECT_ROOT/bin/md2docx"

    if ln -s "$PROJECT_ROOT/bin/md2docx" "$symlink_path" 2>/dev/null; then
        log_success "Symlink created"
        log_info "  md2docx is now available system-wide"
    else
        log_warning "Failed to create symlink (not critical)"
        log_info "CLI can still be used via: $PROJECT_ROOT/bin/md2docx"
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

    log_info "Testing help command..."

    local output
    output=$("$PROJECT_ROOT/bin/md2docx" --help 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "CLI help command failed"
        echo "$output" | head -20 >&2
        return 1
    fi

    if ! echo "$output" | grep -q "Usage:"; then
        log_error "CLI help output seems incorrect"
        echo "$output" | head -20 >&2
        return 1
    fi

    log_success "CLI test passed"
    return 0
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    log_header "DOCX CLI Deployment"

    if is_component_functional "docx-cli"; then
        log_success "DOCX CLI already deployed"
        log_info "Skipping deployment (idempotence)"
        return 0
    fi

    log_info "DOCX CLI not deployed, proceeding with deployment"

    verify_cli_source 1 6 || return 1
    make_cli_executable 2 6 || return 1
    verify_cli_syntax 3 6 || return 1
    configure_shell_aliases 4 6 || return 1
    create_symlink 5 6 || return 1
    test_cli 6 6 || return 1

    if verify_cli_deployed; then
        log_success "DOCX CLI deployment verified"
        mark_installation_state "docx-cli"

        log_info "Deployment details:"
        log_info "  CLI: $PROJECT_ROOT/bin/md2docx"
        log_info "  Aliases: $PROJECT_ROOT/config/shell/docx-aliases.sh"
        log_info "  Symlink: /usr/local/bin/md2docx"

        log_info "Available commands:"
        log_info "  md2docx           - Main conversion command"
        log_info "  md2docx-quick     - Quick conversion with defaults"
        log_info "  docx-config       - Show configuration"
        log_info "  docx-venv         - Activate virtualenv"

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