#!/usr/bin/env bash
# scripts/installation/install-system-dependencies.sh
# Install system-level dependencies (Python, pip, build tools)

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

verify_system_functional() {
    log_debug "Verifying system dependencies"

    local required_commands=(
        "python3"
        "pip3"
    )

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_debug "Command not found: $cmd"
            return 1
        fi
    done

    # Verify Python version
    local py_version
    py_version=$(python3 --version 2>&1 | awk '{print $2}')

    local py_major
    local py_minor
    py_major=$(echo "$py_version" | cut -d. -f1)
    py_minor=$(echo "$py_version" | cut -d. -f2)

    if [[ "$py_major" -lt 3 ]] || [[ "$py_major" -eq 3 && "$py_minor" -lt 6 ]]; then
        log_debug "Python version too old: $py_version (need 3.6+)"
        return 1
    fi

    log_debug "System verification passed"
    return 0
}

# =============================================================================
# STEP 1: UPDATE PACKAGE LISTS
# =============================================================================

update_package_lists() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Updating package lists"

    log_info "Running apt-get update..."

    if ! apt-get update -y 2>&1 | tee -a "$LOG_FILE" | grep -v "^Get:" | grep -v "^Hit:" | grep -v "^Reading" >/dev/null; then
        log_error "Failed to update package lists"
        return 1
    fi

    log_success "Package lists updated"
    return 0
}

# =============================================================================
# STEP 2: INSTALL PYTHON AND TOOLS
# =============================================================================

install_python_stack() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Installing Python stack"

    local packages=(
        "python3"
        "python3-pip"
        "python3-venv"
        "python3-dev"
        "build-essential"
    )

    log_info "Installing packages: ${packages[*]}"

    local install_output
    install_output=$(apt-get install -y "${packages[@]}" 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "Failed to install Python stack"
        echo "$install_output" | tail -20 >&2
        return 1
    fi

    log_success "Python stack installed"

    # Show versions
    local py_version
    py_version=$(python3 --version 2>&1)
    log_info "  $py_version"

    local pip_version
    pip_version=$(pip3 --version 2>&1 | head -1)
    log_info "  $pip_version"

    return 0
}

# =============================================================================
# STEP 3: VERIFY INSTALLATION
# =============================================================================

verify_installation() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Verifying installation"

    local required_commands=(
        "python3"
        "pip3"
    )

    local missing=()

    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_info "  $cmd: OK"
        else
            log_error "  $cmd: MISSING"
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing commands: ${missing[*]}"
        return 1
    fi

    # Test Python can import basic modules
    log_info "Testing Python functionality..."

    if python3 -c "import sys; sys.exit(0)" 2>/dev/null; then
        log_info "  Python import test: OK"
    else
        log_error "  Python import test: FAILED"
        return 1
    fi

    log_success "Installation verified"
    return 0
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    log_header "System Dependencies Installation"

    if is_component_functional "system"; then
        log_success "System dependencies already functional"
        log_info "Skipping installation (idempotence)"
        return 0
    fi

    log_info "System dependencies not functional, proceeding with installation"

    update_package_lists 1 3 || return 1
    install_python_stack 2 3 || return 1
    verify_installation 3 3 || return 1

    if verify_system_functional; then
        log_success "System dependencies installation verified"
        mark_installation_state "system"

        log_info "Installation details:"
        local py_version
        py_version=$(python3 --version 2>&1)
        log_info "  Python: $py_version"

        local pip_version
        pip_version=$(pip3 --version 2>&1 | head -1)
        log_info "  Pip: $pip_version"

        return 0
    else
        log_error "Verification failed after installation"
        return 1
    fi
}

# =============================================================================
# EXECUTION
# =============================================================================

main "$@"
exit $?