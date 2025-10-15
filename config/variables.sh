# =============================================================================
# DOCX PIPELINE CONFIGURATION
# =============================================================================

# Rutas base del pipeline
export DOCX_SRC_DIR="${PROJECT_ROOT}/docs"
export DOCX_IMG_DIR="${DOCX_SRC_DIR}/images"
export DOCX_TPL="${PROJECT_ROOT}/templates/plantilla_corporativa.docx"
export DOCX_STYLE_YML="${PROJECT_ROOT}/templates/style.yml"
export DOCX_BUILD_DIR="${PROJECT_ROOT}/builds"

# Archivos por defecto
export DOCX_INPUT_MD="${DOCX_SRC_DIR}/entrada.md"
export DOCX_OUTPUT_DOCX="${DOCX_BUILD_DIR}/salida_final.docx"

# Virtualenv Python
export DOCX_VENV="${PROJECT_ROOT}/.venv-docx"
export DOCX_PYTHON="${DOCX_VENV}/bin/python"
export DOCX_PIP="${DOCX_VENV}/bin/pip"

# Rutas de scripts
export DOCX_SCRIPTS_DIR="${PROJECT_ROOT}/scripts/mdx"
export DOCX_MAIN_SCRIPT="${DOCX_SCRIPTS_DIR}/md2docx.py"

# Versiones de dependencias
export DOCX_MARKDOWN_VERSION="3.6"
export DOCX_BS4_VERSION="4.12.3"
export DOCX_PYTHON_DOCX_VERSION="1.1.2"
export DOCX_PYYAML_VERSION="6.0.1"

# Configuración de Python
export DOCX_PYTHON_MIN_MAJOR="3"
export DOCX_PYTHON_MIN_MINOR="6"