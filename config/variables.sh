#!/usr/bin/env bash

# Prevent multiple sourcing
if [[ "${CONFIG_VARIABLES_LOADED:-}" == "true" ]]; then
    return 0
fi

# =============================================================================
# PROJECT PATHS
# =============================================================================

# Project root (must be set before sourcing this file)
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    echo "ERROR: PROJECT_ROOT not set" >&2
    return 1
fi

export PROJECT_ROOT

# =============================================================================
# CORE DIRECTORIES
# =============================================================================

export BIN_DIR="${PROJECT_ROOT}/bin"
export CONFIG_DIR="${PROJECT_ROOT}/config"
export SCRIPTS_DIR="${PROJECT_ROOT}/scripts"
export INFRASTRUCTURE_DIR="${PROJECT_ROOT}/infrastructure"
export UTILS_DIR="${INFRASTRUCTURE_DIR}/utils"

# =============================================================================
# APPLICATION DIRECTORIES
# =============================================================================

export APP_BASE_DIR="${PROJECT_ROOT}/.app"
export APP_LOG_DIR="${APP_BASE_DIR}/logs"
export APP_STATE_DIR="${APP_BASE_DIR}/state"
export APP_CACHE_DIR="${APP_BASE_DIR}/cache"

# =============================================================================
# DOCX PIPELINE DIRECTORIES
# =============================================================================

export DOCX_SRC_DIR="${PROJECT_ROOT}/docs"
export DOCX_IMG_DIR="${DOCX_SRC_DIR}/images"
export DOCX_BUILD_DIR="${PROJECT_ROOT}/builds"
export DOCX_SCRIPTS_DIR="${PROJECT_ROOT}/mdx"

# =============================================================================
# DOCX CONFIGURATION FILES
# =============================================================================

# Template removed - all styling is now programmatic via style.yml
# export DOCX_TPL="${PROJECT_ROOT}/templates/plantilla_corporativa.docx"
export DOCX_STYLE_YML="${PROJECT_ROOT}/templates/style.yml"

# =============================================================================
# DOCX DEFAULT FILES
# =============================================================================

export DOCX_INPUT_MD="${DOCX_SRC_DIR}/entrada.md"
export DOCX_OUTPUT_DOCX="${DOCX_BUILD_DIR}/salida_final.docx"

# =============================================================================
# PYTHON VIRTUALENV
# =============================================================================
# NOTE: Virtualenv must be outside /vagrant/ to avoid symlink issues
#       VirtualBox shared folders don't support symlinks required by Python venv

export DOCX_VENV="/home/vagrant/.venv-docx"
export DOCX_PYTHON="${DOCX_VENV}/bin/python"
export DOCX_PIP="${DOCX_VENV}/bin/pip"

# =============================================================================
# PYTHON SCRIPTS
# =============================================================================

export DOCX_MAIN_SCRIPT="${DOCX_SCRIPTS_DIR}/md2docx.py"

# =============================================================================
# DEPENDENCY VERSIONS
# =============================================================================

export DOCX_MARKDOWN_VERSION="3.6"
export DOCX_BS4_VERSION="4.12.3"
export DOCX_PYTHON_DOCX_VERSION="1.1.2"
export DOCX_PYYAML_VERSION="6.0.1"

# =============================================================================
# PYTHON REQUIREMENTS
# =============================================================================

export DOCX_PYTHON_MIN_MAJOR="3"
export DOCX_PYTHON_MIN_MINOR="6"

# =============================================================================
# LOGGING CONFIGURATION
# =============================================================================

export LOG_FILE="${APP_LOG_DIR}/docx-pipeline.log"
export LOG_LEVEL="${LOG_LEVEL:-INFO}"

# =============================================================================
# INSTALLATION TIMEOUTS
# =============================================================================

export INSTALL_TIMEOUT="${INSTALL_TIMEOUT:-1800}"

# =============================================================================
# ADDITIONAL DIRECTORIES (for compatibility)
# =============================================================================

export MODELS_DIR="${PROJECT_ROOT}/models"
export OUTPUT_DIR="${PROJECT_ROOT}/output"
export DIAGRAMS_DIR="${OUTPUT_DIR}/diagrams"
export REPORTS_DIR="${OUTPUT_DIR}/reports"
export TEMPLATES_DIR="${PROJECT_ROOT}/templates"

# =============================================================================
# MARK AS LOADED
# =============================================================================

readonly CONFIG_VARIABLES_LOADED="true"
export CONFIG_VARIABLES_LOADED