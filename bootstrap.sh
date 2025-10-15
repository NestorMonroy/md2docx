#!/usr/bin/env bash
# bootstrap.sh
# Script de inicialización y orquestación del entorno completo

set -euo pipefail

# =============================================================================
# INITIALIZATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# =============================================================================
# COLORS (for terminal output)
# =============================================================================

if [[ -t 1 ]]; then
    readonly COLOR_GREEN='\033[0;32m'
    readonly COLOR_BLUE='\033[0;34m'
    readonly COLOR_YELLOW='\033[1;33m'
    readonly COLOR_RED='\033[0;31m'
    readonly COLOR_RESET='\033[0m'
else
    readonly COLOR_GREEN=''
    readonly COLOR_BLUE=''
    readonly COLOR_YELLOW=''
    readonly COLOR_RED=''
    readonly COLOR_RESET=''
fi

# =============================================================================
# LOGGING FUNCTIONS (Simple fallback)
# =============================================================================

log_header() {
    echo ""
    echo "============================================================"
    echo "  $*"
    echo "============================================================"
}

log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $*"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*"
}

log_step() {
    echo -e "${COLOR_BLUE}[STEP $1/$2]${COLOR_RESET} $3"
}

# =============================================================================
# VALIDATE ENVIRONMENT
# =============================================================================

validate_environment() {
    log_info "Validating environment..."

    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        log_info "Run: sudo bash bootstrap.sh"
        return 1
    fi

    if [[ ! -f "$PROJECT_ROOT/config/variables.sh" ]]; then
        log_error "config/variables.sh not found"
        log_error "Ensure you're running from project root"
        return 1
    fi

    log_success "Environment validation passed"
    return 0
}

# =============================================================================
# CHECK COMPONENT STATUS
# =============================================================================

check_component_installed() {
    local component="$1"
    local state_dir="$PROJECT_ROOT/.state"
    local state_file="$state_dir/${component}.installed"

    if [[ -f "$state_file" ]]; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# STEP 1: SYSTEM DEPENDENCIES
# =============================================================================

step_install_system_dependencies() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Installing System Dependencies"

    local script="$PROJECT_ROOT/scripts/installation/install-system-dependencies.sh"

    if [[ ! -f "$script" ]]; then
        log_warning "System dependencies installer not found, skipping"
        log_warning "Expected: $script"
        return 0
    fi

    if check_component_installed "system"; then
        log_info "System dependencies already installed (idempotence)"
        return 0
    fi

    log_info "Executing: $script"
    if bash "$script"; then
        log_success "System dependencies installed"
        return 0
    else
        log_error "Failed to install system dependencies"
        return 1
    fi
}

# =============================================================================
# STEP 2: DOCX STACK
# =============================================================================

step_install_docx_stack() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Installing DOCX Stack"

    local script="$PROJECT_ROOT/scripts/installation/install-docx-stack.sh"

    if [[ ! -f "$script" ]]; then
        log_error "DOCX stack installer not found: $script"
        return 1
    fi

    if check_component_installed "docx-stack"; then
        log_info "DOCX stack already installed (idempotence)"
        return 0
    fi

    log_info "Executing: $script"
    if bash "$script"; then
        log_success "DOCX stack installed"
        return 0
    else
        log_error "Failed to install DOCX stack"
        return 1
    fi
}

# =============================================================================
# STEP 3: CONFIGURE PIPELINE
# =============================================================================

step_configure_docx_pipeline() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Configuring DOCX Pipeline"

    local script="$PROJECT_ROOT/scripts/setup/configure-docx-pipeline.sh"

    if [[ ! -f "$script" ]]; then
        log_error "DOCX pipeline configurator not found: $script"
        return 1
    fi

    if check_component_installed "docx-pipeline"; then
        log_info "DOCX pipeline already configured (idempotence)"
        return 0
    fi

    log_info "Executing: $script"
    if bash "$script"; then
        log_success "DOCX pipeline configured"
        return 0
    else
        log_error "Failed to configure DOCX pipeline"
        return 1
    fi
}

# =============================================================================
# STEP 4: DEPLOY PYTHON SCRIPTS
# =============================================================================

step_deploy_docx_scripts() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Deploying DOCX Python Scripts"

    local script="$PROJECT_ROOT/scripts/setup/deploy-docx-scripts.sh"

    if [[ ! -f "$script" ]]; then
        log_error "DOCX scripts deployer not found: $script"
        return 1
    fi

    if check_component_installed "docx-scripts"; then
        log_info "DOCX scripts already deployed (idempotence)"
        return 0
    fi

    log_info "Executing: $script"
    if bash "$script"; then
        log_success "DOCX scripts deployed"
        return 0
    else
        log_error "Failed to deploy DOCX scripts"
        return 1
    fi
}

# =============================================================================
# STEP 5: DEPLOY CLI
# =============================================================================

step_deploy_docx_cli() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Deploying DOCX CLI"

    local script="$PROJECT_ROOT/scripts/setup/deploy-docx-cli.sh"

    if [[ ! -f "$script" ]]; then
        log_error "DOCX CLI deployer not found: $script"
        return 1
    fi

    if check_component_installed "docx-cli"; then
        log_info "DOCX CLI already deployed (idempotence)"
        return 0
    fi

    log_info "Executing: $script"
    if bash "$script"; then
        log_success "DOCX CLI deployed"
        return 0
    else
        log_error "Failed to deploy DOCX CLI"
        return 1
    fi
}

# =============================================================================
# STEP 6: VERIFY INSTALLATION
# =============================================================================

step_verify_installation() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Verifying Installation"

    local script="$PROJECT_ROOT/scripts/setup/verify-docx-pipeline.sh"

    if [[ ! -f "$script" ]]; then
        log_warning "Verification script not found, skipping"
        return 0
    fi

    log_info "Running verification tests..."

    # Run as non-root user (vagrant) if available
    if id vagrant &>/dev/null; then
        if sudo -u vagrant bash "$script"; then
            log_success "Verification passed"
            return 0
        else
            log_warning "Some verification tests failed"
            return 0  # Don't fail bootstrap on verification warnings
        fi
    else
        if bash "$script"; then
            log_success "Verification passed"
            return 0
        else
            log_warning "Some verification tests failed"
            return 0
        fi
    fi
}

# =============================================================================
# COMPLETION MESSAGE
# =============================================================================

show_completion_message() {
    log_header "Bootstrap Completed Successfully"

    echo ""
    echo "The DOCX pipeline has been installed and configured."
    echo ""
    echo "Quick Start:"
    echo "  1. Run conversion: md2docx"
    echo "  2. Check output:   ls -lh builds/"
    echo ""
    echo "Commands available:"
    echo "  md2docx           - Convert Markdown to DOCX"
    echo "  md2docx-quick     - Quick conversion with defaults"
    echo "  docx-config       - Show configuration"
    echo "  docx-venv         - Activate Python virtualenv"
    echo ""
    echo "Examples:"
    echo "  md2docx docs/entrada.md builds/salida.docx"
    echo "  generate docx docs/report.md builds/report.docx"
    echo ""
    echo "Documentation:"
    echo "  README: $PROJECT_ROOT/README-DOCX-PIPELINE.md"
    echo ""
    echo "To reload aliases in current shell:"
    echo "  source ~/.bashrc"
    echo ""
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    log_header "DOCX Pipeline Bootstrap"

    echo ""
    echo "This script will install and configure the complete DOCX pipeline."
    echo ""
    echo "Project root: $PROJECT_ROOT"
    echo ""

    # Validate environment
    if ! validate_environment; then
        exit 1
    fi

    local total_steps=6
    local current_step=0

    # Step 1: System dependencies (optional)
    ((current_step++))
    if ! step_install_system_dependencies "$current_step" "$total_steps"; then
        log_warning "System dependencies step had issues, continuing..."
    fi

    # Step 2: DOCX stack (required)
    ((current_step++))
    if ! step_install_docx_stack "$current_step" "$total_steps"; then
        log_error "Failed at step $current_step: DOCX stack installation"
        exit 1
    fi

    # Step 3: Configure pipeline (required)
    ((current_step++))
    if ! step_configure_docx_pipeline "$current_step" "$total_steps"; then
        log_error "Failed at step $current_step: Pipeline configuration"
        exit 1
    fi

    # Step 4: Deploy scripts (required)
    ((current_step++))
    if ! step_deploy_docx_scripts "$current_step" "$total_steps"; then
        log_error "Failed at step $current_step: Scripts deployment"
        exit 1
    fi

    # Step 5: Deploy CLI (required)
    ((current_step++))
    if ! step_deploy_docx_cli "$current_step" "$total_steps"; then
        log_error "Failed at step $current_step: CLI deployment"
        exit 1
    fi

    # Step 6: Verify (optional)
    ((current_step++))
    if ! step_verify_installation "$current_step" "$total_steps"; then
        log_warning "Verification had warnings, but installation completed"
    fi

    # Show completion message
    show_completion_message

    return 0
}

# =============================================================================
# EXECUTION
# =============================================================================

main "$@"
exit $?