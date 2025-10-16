#!/usr/bin/env bash
# config/shell/docx-aliases.sh
# Aliases for DOCX pipeline

# NOTE: Do NOT use 'set -euo pipefail' here as this file is sourced by .bashrc
#       and any error would interrupt the shell login process

# =============================================================================
# LOAD VARIABLES
# =============================================================================

load_docx_variables() {
    # Try multiple locations for variables.sh
    local variables_loaded=false

    # 1. Try deployed location first (most reliable)
    if [[ -f "/usr/local/share/config/variables.sh" ]]; then
        # shellcheck source=/dev/null
        source "/usr/local/share/config/variables.sh" 2>/dev/null && variables_loaded=true
    fi

    # 2. Try to derive from this script's location
    if [[ "$variables_loaded" == "false" ]]; then
        local aliases_script_dir
        aliases_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || return 1
        local aliases_config_dir
        aliases_config_dir="$(cd "$aliases_script_dir/.." 2>/dev/null && pwd)" || return 1

        if [[ -f "$aliases_config_dir/variables.sh" ]]; then
            # shellcheck source=/dev/null
            source "$aliases_config_dir/variables.sh" 2>/dev/null && variables_loaded=true
        fi
    fi

    # 3. Try /vagrant as fallback (Vagrant environment)
    if [[ "$variables_loaded" == "false" ]] && [[ -f "/vagrant/config/variables.sh" ]]; then
        # Set PROJECT_ROOT for variables.sh to work
        export PROJECT_ROOT="/vagrant"
        # shellcheck source=/dev/null
        source "/vagrant/config/variables.sh" 2>/dev/null && variables_loaded=true
    fi

    if [[ "$variables_loaded" == "false" ]]; then
        # Silent failure - don't break shell initialization
        return 1
    fi

    return 0
}

# Load variables (suppress output to avoid polluting shell initialization)
if ! load_docx_variables 2>/dev/null; then
    # If loading fails, define minimal stubs to prevent errors
    md2docx() {
        echo "ERROR: DOCX environment not loaded" >&2
        echo "Try running: source /vagrant/config/shell/docx-aliases.sh" >&2
        return 1
    }

    md2docx-quick() {
        echo "ERROR: DOCX environment not loaded" >&2
        return 1
    }

    docx-config() {
        echo "ERROR: DOCX environment not loaded" >&2
        return 1
    }

    docx-venv() {
        echo "ERROR: DOCX environment not loaded" >&2
        return 1
    }

    # Export stub functions
    export -f md2docx
    export -f md2docx-quick
    export -f docx-config
    export -f docx-venv

    # Return early
    return 0
fi

# =============================================================================
# DOCX PIPELINE ALIASES (only defined if variables loaded successfully)
# =============================================================================

# Main conversion command
md2docx() {
    # Try system-wide installed CLI first
    if command -v /usr/local/bin/md2docx >/dev/null 2>&1; then
        /usr/local/bin/md2docx "$@"
        return $?
    fi

    # Fallback to project bin directory
    if [[ -n "${PROJECT_ROOT:-}" ]] && [[ -x "${PROJECT_ROOT}/bin/md2docx" ]]; then
        "${PROJECT_ROOT}/bin/md2docx" "$@"
        return $?
    fi

    echo "ERROR: md2docx not found" >&2
    echo "Tried locations:" >&2
    echo "  /usr/local/bin/md2docx" >&2
    echo "  ${PROJECT_ROOT:-unset}/bin/md2docx" >&2
    echo "" >&2
    echo "Run deployment: sudo bash scripts/setup/deploy-docx-scripts.sh" >&2
    return 1
}

# Quick conversion with default paths
md2docx-quick() {
    if [[ -z "${DOCX_INPUT_MD:-}" ]] || [[ -z "${DOCX_OUTPUT_DOCX:-}" ]]; then
        echo "ERROR: Default paths not configured" >&2
        echo "DOCX_INPUT_MD: ${DOCX_INPUT_MD:-not set}" >&2
        echo "DOCX_OUTPUT_DOCX: ${DOCX_OUTPUT_DOCX:-not set}" >&2
        return 1
    fi

    md2docx "${DOCX_INPUT_MD}" "${DOCX_OUTPUT_DOCX}"
}

# Show DOCX configuration
docx-config() {
    cat << EOF
DOCX Pipeline Configuration
============================

Directories:
  Source dir:    ${DOCX_SRC_DIR:-not set}
  Images dir:    ${DOCX_IMG_DIR:-not set}
  Build dir:     ${DOCX_BUILD_DIR:-not set}
  Scripts dir:   ${DOCX_SCRIPTS_DIR:-not set}

Templates:
  DOCX template: ${DOCX_TPL:-not set}
  Style config:  ${DOCX_STYLE_YML:-not set}

Python Environment:
  Virtualenv:    ${DOCX_VENV:-not set}
  Python:        ${DOCX_PYTHON:-not set}
  Main script:   ${DOCX_MAIN_SCRIPT:-not set}

Default Files:
  Input:         ${DOCX_INPUT_MD:-not set}
  Output:        ${DOCX_OUTPUT_DOCX:-not set}

Commands:
  md2docx:       $(command -v md2docx 2>/dev/null || echo "not in PATH")
  System CLI:    $(if [[ -x /usr/local/bin/md2docx ]]; then echo "installed"; else echo "not installed"; fi)

Project:
  Root:          ${PROJECT_ROOT:-not set}

EOF
}

# Activate DOCX virtualenv
docx-venv() {
    if [[ -z "${DOCX_VENV:-}" ]]; then
        echo "ERROR: DOCX_VENV not set" >&2
        return 1
    fi

    if [[ ! -f "${DOCX_VENV}/bin/activate" ]]; then
        echo "ERROR: Virtualenv not found at: ${DOCX_VENV}" >&2
        echo "" >&2
        echo "Run installation: sudo bash scripts/installation/install-docx-stack.sh" >&2
        return 1
    fi

    # shellcheck source=/dev/null
    source "${DOCX_VENV}/bin/activate"
    echo "✓ DOCX virtualenv activated: ${DOCX_VENV}"
}

# Navigation helpers
docx-docs() {
    if [[ -n "${DOCX_SRC_DIR:-}" ]] && [[ -d "${DOCX_SRC_DIR}" ]]; then
        cd "${DOCX_SRC_DIR}" || return 1
        echo "Now in: ${DOCX_SRC_DIR}"
    else
        echo "ERROR: DOCX_SRC_DIR not set or doesn't exist" >&2
        return 1
    fi
}

docx-builds() {
    if [[ -n "${DOCX_BUILD_DIR:-}" ]]; then
        mkdir -p "${DOCX_BUILD_DIR}" 2>/dev/null
        cd "${DOCX_BUILD_DIR}" || return 1
        echo "Now in: ${DOCX_BUILD_DIR}"
    else
        echo "ERROR: DOCX_BUILD_DIR not set" >&2
        return 1
    fi
}

docx-root() {
    if [[ -n "${PROJECT_ROOT:-}" ]] && [[ -d "${PROJECT_ROOT}" ]]; then
        cd "${PROJECT_ROOT}" || return 1
        echo "Now in: ${PROJECT_ROOT}"
    else
        echo "ERROR: PROJECT_ROOT not set or doesn't exist" >&2
        return 1
    fi
}

# Help command
docx-help() {
    cat << 'EOF'
DOCX Pipeline Commands
======================

Conversion:
  md2docx INPUT OUTPUT  - Convert Markdown to DOCX
  md2docx-quick         - Quick conversion using defaults
  md2docx --help        - Show detailed help

Configuration:
  docx-config           - Show current configuration
  docx-venv             - Activate Python virtualenv

Navigation:
  docx-docs             - Go to docs directory
  docx-builds           - Go to builds directory
  docx-root             - Go to project root

Examples:
  md2docx docs/entrada.md builds/output.docx
  md2docx-quick
  docx-config

For detailed CLI help:
  md2docx --help

EOF
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f md2docx
export -f md2docx-quick
export -f docx-config
export -f docx-venv
export -f docx-docs 2>/dev/null || true
export -f docx-builds 2>/dev/null || true
export -f docx-root 2>/dev/null || true
export -f docx-help 2>/dev/null || true