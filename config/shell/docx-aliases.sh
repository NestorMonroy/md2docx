#!/usr/bin/env bash
# config/shell/docx-aliases.sh
# Aliases for DOCX pipeline

set -euo pipefail

# =============================================================================
# LOAD VARIABLES
# =============================================================================

ALIASES_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALIASES_CONFIG_DIR="$(cd "$ALIASES_SCRIPT_DIR/.." && pwd)"

if [[ -f "$ALIASES_CONFIG_DIR/variables.sh" ]]; then
    # shellcheck source=/dev/null
    source "$ALIASES_CONFIG_DIR/variables.sh"
else
    echo "ERROR: Cannot load variables.sh from: $ALIASES_CONFIG_DIR" >&2
    return 1
fi

# =============================================================================
# DOCX PIPELINE ALIASES
# =============================================================================

# Main conversion command
md2docx() {
    if [[ ! -x "${PROJECT_ROOT}/bin/md2docx" ]]; then
        echo "ERROR: md2docx not found or not executable" >&2
        echo "Location: ${PROJECT_ROOT}/bin/md2docx" >&2
        return 1
    fi

    "${PROJECT_ROOT}/bin/md2docx" "$@"
}

# Quick conversion with default paths
md2docx-quick() {
    md2docx "${DOCX_INPUT_MD}" "${DOCX_OUTPUT_DOCX}"
}

# Show DOCX configuration
docx-config() {
    echo "DOCX Pipeline Configuration:"
    echo "  Source dir:    ${DOCX_SRC_DIR}"
    echo "  Images dir:    ${DOCX_IMG_DIR}"
    echo "  Template:      ${DOCX_TPL}"
    echo "  Style config:  ${DOCX_STYLE_YML}"
    echo "  Build dir:     ${DOCX_BUILD_DIR}"
    echo "  Virtualenv:    ${DOCX_VENV}"
    echo "  Python:        ${DOCX_PYTHON}"
    echo "  Main script:   ${DOCX_MAIN_SCRIPT}"
}

# Activate DOCX virtualenv
docx-venv() {
    if [[ ! -f "${DOCX_VENV}/bin/activate" ]]; then
        echo "ERROR: Virtualenv not found at: ${DOCX_VENV}" >&2
        echo "Run: sudo bash scripts/installation/install-docx-stack.sh" >&2
        return 1
    fi

    # shellcheck source=/dev/null
    source "${DOCX_VENV}/bin/activate"
    echo "DOCX virtualenv activated"
}

# Export functions
export -f md2docx
export -f md2docx-quick
export -f docx-config
export -f docx-venv