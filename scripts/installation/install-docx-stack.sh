#!/usr/bin/env bash
# scripts/installation/install-docx-stack.sh
# Install DOCX pipeline Python stack (idempotent)

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

    local missing=()

    if ! command -v python3 >/dev/null 2>&1; then
        missing+=("python3")
    fi

    if ! command -v pip3 >/dev/null 2>&1; then
        missing+=("python3-pip")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required packages: ${missing[*]}"
        log_error "Run: sudo apt-get install -y ${missing[*]}"
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

verify_docx_stack_functional() {
    log_debug "Verifying DOCX stack functionality"

    # Check virtualenv exists
    if [[ ! -d "$DOCX_VENV" ]]; then
        log_debug "Virtualenv not found: $DOCX_VENV"
        return 1
    fi

    # Check Python executable exists
    if [[ ! -f "$DOCX_PYTHON" ]]; then
        log_debug "Python executable not found: $DOCX_PYTHON"
        return 1
    fi

    # Check pip executable exists
    if [[ ! -f "$DOCX_PIP" ]]; then
        log_debug "Pip executable not found: $DOCX_PIP"
        return 1
    fi

    # Check Python version
    local py_version
    py_version=$("$DOCX_PYTHON" --version 2>&1 | awk '{print $2}' || echo "")

    if [[ -z "$py_version" ]]; then
        log_debug "Cannot determine Python version"
        return 1
    fi

    local py_major
    local py_minor
    py_major=$(echo "$py_version" | cut -d. -f1)
    py_minor=$(echo "$py_version" | cut -d. -f2)

    if [[ "$py_major" -lt "$DOCX_PYTHON_MIN_MAJOR" ]] || \
       [[ "$py_major" -eq "$DOCX_PYTHON_MIN_MAJOR" && "$py_minor" -lt "$DOCX_PYTHON_MIN_MINOR" ]]; then
        log_debug "Python version too old: $py_version (need ${DOCX_PYTHON_MIN_MAJOR}.${DOCX_PYTHON_MIN_MINOR}+)"
        return 1
    fi

    # Check required modules
    local required_modules=("markdown" "bs4" "docx" "yaml")
    local missing_modules=()

    for module in "${required_modules[@]}"; do
        if ! "$DOCX_PYTHON" -c "import $module" 2>/dev/null; then
            missing_modules+=("$module")
        fi
    done

    if [[ ${#missing_modules[@]} -gt 0 ]]; then
        log_debug "Missing Python modules: ${missing_modules[*]}"
        return 1
    fi

    # Verify markdown can convert
    local test_result
    test_result=$("$DOCX_PYTHON" -c "import markdown; print(markdown.markdown('# Test'))" 2>&1 || echo "")

    if ! echo "$test_result" | grep -q "<h1>Test</h1>"; then
        log_debug "Markdown conversion test failed"
        return 1
    fi

    log_debug "DOCX stack verification passed"
    return 0
}

# =============================================================================
# STEP 1: INSTALL SYSTEM DEPENDENCIES
# =============================================================================

install_system_dependencies() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Installing system dependencies"

    log_info "Updating package lists..."
    if ! apt-get update -y 2>&1 | tee -a "$LOG_FILE" | grep -v "^Get:" | grep -v "^Hit:" | grep -v "^Reading" >/dev/null; then
        log_error "Failed to update package lists"
        return 1
    fi

    local packages=(
        "python3"
        "python3-venv"
        "python3-pip"
        "python3-dev"
        "build-essential"
    )

    log_info "Installing packages: ${packages[*]}"

    local install_output
    install_output=$(apt-get install -y "${packages[@]}" 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "Failed to install system dependencies"
        echo "$install_output" | tail -20 >&2
        return 1
    fi

    # Verify installation
    for pkg in python3 python3-venv pip3; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            log_error "Package not found after installation: $pkg"
            return 1
        fi
    done

    log_success "System dependencies installed"

    local py_version
    py_version=$(python3 --version 2>&1)
    log_info "  $py_version"

    return 0
}

# =============================================================================
# STEP 2: CREATE VIRTUALENV
# =============================================================================

create_virtualenv() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Creating Python virtualenv"

    if [[ -d "$DOCX_VENV" ]]; then
        log_info "Virtualenv already exists: $DOCX_VENV"

        # Verify it's functional
        if [[ -f "$DOCX_PYTHON" ]]; then
            log_info "Virtualenv appears functional, skipping creation"
            return 0
        else
            log_warning "Virtualenv exists but appears broken, recreating..."
            rm -rf "$DOCX_VENV"
        fi
    fi

    local venv_dir
    venv_dir=$(dirname "$DOCX_VENV")

    if [[ ! -d "$venv_dir" ]]; then
        log_info "Creating parent directory: $venv_dir"
        if ! mkdir -p "$venv_dir"; then
            log_error "Failed to create directory: $venv_dir"
            return 1
        fi
    fi

    log_info "Creating virtualenv at: $DOCX_VENV"

    local venv_output
    venv_output=$(python3 -m venv "$DOCX_VENV" 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "Failed to create virtualenv"
        echo "$venv_output" >&2
        return 1
    fi

    # Verify creation
    if [[ ! -f "$DOCX_PYTHON" ]]; then
        log_error "Python executable not found after venv creation"
        return 1
    fi

    if [[ ! -f "$DOCX_PIP" ]]; then
        log_error "Pip executable not found after venv creation"
        return 1
    fi

    log_success "Virtualenv created"
    log_info "  Location: $DOCX_VENV"
    log_info "  Python: $DOCX_PYTHON"

    return 0
}

# =============================================================================
# STEP 3: UPGRADE PIP
# =============================================================================

upgrade_pip() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Upgrading pip"

    log_info "Upgrading pip to latest version..."

    local pip_output
    pip_output=$("$DOCX_PIP" install --upgrade pip 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "Failed to upgrade pip"
        echo "$pip_output" | tail -20 >&2
        return 1
    fi

    # Get pip version
    local pip_version
    pip_version=$("$DOCX_PIP" --version 2>&1 || echo "unknown")

    log_success "Pip upgraded"
    log_info "  $pip_version"

    return 0
}

# =============================================================================
# STEP 4: INSTALL PYTHON DEPENDENCIES
# =============================================================================

install_python_dependencies() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Installing Python dependencies"

    local packages=(
        "markdown==${DOCX_MARKDOWN_VERSION}"
        "beautifulsoup4==${DOCX_BS4_VERSION}"
        "python-docx==${DOCX_PYTHON_DOCX_VERSION}"
        "PyYAML==${DOCX_PYYAML_VERSION}"
    )

    log_info "Installing packages:"
    for pkg in "${packages[@]}"; do
        log_info "  - $pkg"
    done

    local install_output
    install_output=$("$DOCX_PIP" install "${packages[@]}" 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "Failed to install Python dependencies"
        echo "$install_output" | tail -30 >&2
        return 1
    fi

    # Verify installations
    local modules_to_verify=(
        "markdown"
        "bs4"
        "docx"
        "yaml"
    )

    local missing=()
    for module in "${modules_to_verify[@]}"; do
        if ! "$DOCX_PYTHON" -c "import $module" 2>/dev/null; then
            missing+=("$module")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Failed to import modules: ${missing[*]}"
        return 1
    fi

    log_success "Python dependencies installed"

    # Show installed versions
    log_info "Installed versions:"
    "$DOCX_PIP" list | grep -E "(markdown|beautifulsoup4|python-docx|PyYAML)" | while read -r line; do
        log_info "  $line"
    done

    return 0
}

# =============================================================================
# STEP 5: VERIFY INSTALLATION
# =============================================================================

verify_installation() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Verifying installation"

    # Test markdown conversion
    log_info "Testing markdown conversion..."
    local md_test
    md_test=$("$DOCX_PYTHON" -c "import markdown; print(markdown.markdown('# Test Heading'))" 2>&1)

    if ! echo "$md_test" | grep -q "<h1>Test Heading</h1>"; then
        log_error "Markdown conversion test failed"
        echo "$md_test" >&2
        return 1
    fi
    log_info "  Markdown: OK"

    # Test BeautifulSoup parsing
    log_info "Testing HTML parsing..."
    local bs_test
    bs_test=$("$DOCX_PYTHON" -c "from bs4 import BeautifulSoup; soup = BeautifulSoup('<p>test</p>', 'html.parser'); print(soup.p.text)" 2>&1)

    if [[ "$bs_test" != "test" ]]; then
        log_error "BeautifulSoup test failed"
        echo "$bs_test" >&2
        return 1
    fi
    log_info "  BeautifulSoup: OK"

    # Test python-docx
    log_info "Testing python-docx..."
    local docx_test
    docx_test=$("$DOCX_PYTHON" -c "from docx import Document; doc = Document(); print('OK')" 2>&1)

    if [[ "$docx_test" != "OK" ]]; then
        log_error "python-docx test failed"
        echo "$docx_test" >&2
        return 1
    fi
    log_info "  python-docx: OK"

    # Test YAML
    log_info "Testing PyYAML..."
    local yaml_test
    yaml_test=$("$DOCX_PYTHON" -c "import yaml; print(yaml.safe_load('test: value')['test'])" 2>&1)

    if [[ "$yaml_test" != "value" ]]; then
        log_error "PyYAML test failed"
        echo "$yaml_test" >&2
        return 1
    fi
    log_info "  PyYAML: OK"

    log_success "All verification tests passed"

    return 0
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    log_header "DOCX Stack Installation"

    if is_component_functional "docx-stack"; then
        log_success "DOCX stack already functional"
        log_info "Skipping installation (idempotence)"
        return 0
    fi

    log_info "DOCX stack not functional, proceeding with installation"

    install_system_dependencies 1 5 || return 1
    create_virtualenv 2 5 || return 1
    upgrade_pip 3 5 || return 1
    install_python_dependencies 4 5 || return 1
    verify_installation 5 5 || return 1

    if verify_docx_stack_functional; then
        log_success "DOCX stack installation verified"
        mark_installation_state "docx-stack"

        log_info "Installation details:"
        log_info "  Virtualenv: $DOCX_VENV"
        log_info "  Python: $DOCX_PYTHON"
        log_info "  Pip: $DOCX_PIP"

        local py_version
        py_version=$("$DOCX_PYTHON" --version 2>&1)
        log_info "  Version: $py_version"

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