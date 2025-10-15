#!/usr/bin/env bash
# scripts/setup/configure-docx-pipeline.sh
# Configure DOCX pipeline directories and permissions (idempotent)

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

    # Check if DOCX stack is installed
    if ! is_component_functional "docx-stack"; then
        log_error "DOCX stack not installed"
        log_error "Run: sudo bash scripts/installation/install-docx-stack.sh"
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

verify_docx_pipeline_configured() {
    log_debug "Verifying DOCX pipeline configuration"

    # Check required directories exist
    local required_dirs=(
        "$DOCX_SRC_DIR"
        "$DOCX_IMG_DIR"
        "$DOCX_BUILD_DIR"
    )

    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_debug "Directory missing: $dir"
            return 1
        fi
    done

    # Check template exists
    if [[ ! -f "$DOCX_TPL" ]]; then
        log_debug "Template missing: $DOCX_TPL"
        return 1
    fi

    # Check style config exists
    if [[ ! -f "$DOCX_STYLE_YML" ]]; then
        log_debug "Style config missing: $DOCX_STYLE_YML"
        return 1
    fi

    # Check scripts directory exists
    if [[ ! -d "$DOCX_SCRIPTS_DIR" ]]; then
        log_debug "Scripts directory missing: $DOCX_SCRIPTS_DIR"
        return 1
    fi

    # Check CLI is executable
    if [[ ! -x "$PROJECT_ROOT/bin/md2docx" ]]; then
        log_debug "CLI not executable: $PROJECT_ROOT/bin/md2docx"
        return 1
    fi

    log_debug "DOCX pipeline configuration verified"
    return 0
}

# =============================================================================
# STEP 1: CREATE DIRECTORY STRUCTURE
# =============================================================================

create_directory_structure() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Creating directory structure"

    local directories=(
        "$DOCX_SRC_DIR"
        "$DOCX_IMG_DIR"
        "$DOCX_BUILD_DIR"
        "$DOCX_SCRIPTS_DIR"
        "$(dirname "$DOCX_TPL")"
    )

    local created=0
    local existing=0
    local failed=0

    for dir in "${directories[@]}"; do
        if [[ -d "$dir" ]]; then
            log_debug "Already exists: $dir"
            ((existing++))
        else
            log_info "Creating: $dir"
            if mkdir -p "$dir" 2>/dev/null; then
                ((created++))
            else
                log_error "Failed to create: $dir"
                ((failed++))
            fi
        fi
    done

    log_info "Directory creation summary:"
    log_info "  Created: $created"
    log_info "  Existing: $existing"

    if [[ $failed -gt 0 ]]; then
        log_info "  Failed: $failed"
        return 1
    fi

    log_success "Directory structure created"
    return 0
}

# =============================================================================
# STEP 2: CONFIGURE PERMISSIONS
# =============================================================================

configure_permissions() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Configuring permissions"

    local directories=(
        "$DOCX_SRC_DIR"
        "$DOCX_IMG_DIR"
        "$DOCX_BUILD_DIR"
        "$DOCX_SCRIPTS_DIR"
    )

    log_info "Setting directory permissions (755)..."
    for dir in "${directories[@]}"; do
        if [[ -d "$dir" ]]; then
            if chmod 755 "$dir" 2>/dev/null; then
                log_debug "Permissions set: $dir"
            else
                log_warning "Failed to set permissions: $dir"
            fi
        fi
    done

    # Make CLI executable if it exists
    if [[ -f "$PROJECT_ROOT/bin/md2docx" ]]; then
        log_info "Making CLI executable: bin/md2docx"
        if chmod +x "$PROJECT_ROOT/bin/md2docx" 2>/dev/null; then
            log_debug "CLI is now executable"
        else
            log_warning "Failed to make CLI executable (will be fixed during deployment)"
        fi
    fi

    log_success "Permissions configured"
    return 0
}

# =============================================================================
# STEP 3: VALIDATE TEMPLATE
# =============================================================================

validate_template() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Validating template"

    if [[ ! -f "$DOCX_TPL" ]]; then
        log_warning "Template not found: $DOCX_TPL"
        log_warning "You must provide a Word template (.docx) with required styles"
        log_info "Required styles in template:"
        log_info "  - Heading 1, Heading 2, Heading 3, Heading 4"
        log_info "  - Normal"
        log_info "  - Code"
        log_info "  - Intense Emphasis"
        log_info "  - List Bullet, List Number"
        log_info "  - Table Grid"
        log_info "  - Quote"

        log_info "Creating placeholder template marker..."
        local template_dir
        template_dir="$(dirname "$DOCX_TPL")"

        if [[ ! -d "$template_dir" ]]; then
            mkdir -p "$template_dir"
        fi

        echo "PLACEHOLDER - Replace with actual Word template" > "${DOCX_TPL}.MISSING"

        log_warning "ACCION REQUERIDA: Create Word template at: $DOCX_TPL"
        return 0
    fi

    # Check if it's a valid DOCX file (ZIP archive)
    local file_type
    file_type=$(file -b --mime-type "$DOCX_TPL" 2>/dev/null || echo "unknown")

    if [[ "$file_type" != "application/vnd.openxmlformats-officedocument.wordprocessingml.document" ]] && \
       [[ "$file_type" != "application/zip" ]]; then
        log_warning "Template may not be a valid DOCX file"
        log_warning "File type detected: $file_type"
        log_warning "Expected: application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    else
        log_success "Template file validated"
        log_info "  Location: $DOCX_TPL"

        local file_size
        file_size=$(stat -c%s "$DOCX_TPL" 2>/dev/null || echo "0")
        log_info "  Size: $((file_size / 1024)) KB"
    fi

    return 0
}

# =============================================================================
# STEP 4: VALIDATE STYLE CONFIG
# =============================================================================

validate_style_config() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Validating style configuration"

    if [[ ! -f "$DOCX_STYLE_YML" ]]; then
        log_warning "Style config not found: $DOCX_STYLE_YML"
        log_info "Creating default style configuration..."

        cat > "$DOCX_STYLE_YML" << 'EOF'
# DOCX Style Mapping Configuration

styles:
  headings:
    h1: "Heading 1"
    h2: "Heading 2"
    h3: "Heading 3"
    h4: "Heading 4"
  paragraph: "Normal"
  code_block: "Code"
  inline_code: "Intense Emphasis"
  bullet_list: "List Bullet"
  number_list: "List Number"
  table: "Table Grid"
  blockquote: "Quote"

behaviors:
  hr_as_page_break: true

images:
  default_width_inches: 5.5
EOF

        if [[ ! -f "$DOCX_STYLE_YML" ]]; then
            log_error "Failed to create style configuration"
            return 1
        fi

        log_success "Default style configuration created"
    else
        log_info "Style configuration found: $DOCX_STYLE_YML"

        # Validate YAML syntax
        if command -v "$DOCX_PYTHON" >/dev/null 2>&1; then
            local yaml_test
            yaml_test=$("$DOCX_PYTHON" -c "import yaml; yaml.safe_load(open('$DOCX_STYLE_YML'))" 2>&1)
            local exit_code=$?

            if [[ $exit_code -eq 0 ]]; then
                log_success "Style configuration is valid YAML"
            else
                log_warning "Style configuration may have YAML syntax errors"
                echo "$yaml_test" | head -5 >&2
            fi
        fi
    fi

    return 0
}

# =============================================================================
# STEP 5: CREATE EXAMPLE INPUT
# =============================================================================

create_example_input() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Creating example input"

    if [[ -f "$DOCX_INPUT_MD" ]]; then
        log_info "Example input already exists: $DOCX_INPUT_MD"
        return 0
    fi

    log_info "Creating example Markdown file..."

    cat > "$DOCX_INPUT_MD" << 'EOF'
# Documento de Ejemplo

Este es un documento de ejemplo para probar el pipeline Markdown → DOCX.

## Características Soportadas

### Texto Formateado

Este es un párrafo normal con **texto en negrita** y *texto en cursiva*.

También podemos incluir `código inline` dentro del texto.

### Listas

Lista sin orden:

- Primer elemento
- Segundo elemento
- Tercer elemento

Lista ordenada:

1. Primer paso
2. Segundo paso
3. Tercer paso

### Código

Bloque de código:

```python
def hello_world():
    print("Hello, World!")
    return True
```

### Tablas

| Columna 1 | Columna 2 | Columna 3 |
|-----------|-----------|-----------|
| Dato 1    | Dato 2    | Dato 3    |
| Dato 4    | Dato 5    | Dato 6    |

---

## Separadores

Los separadores horizontales se convierten en saltos de página.

---

## Conclusión

Este documento demuestra las capacidades básicas del pipeline.
EOF

    if [[ ! -f "$DOCX_INPUT_MD" ]]; then
        log_error "Failed to create example input"
        return 1
    fi

    log_success "Example input created"
    log_info "  Location: $DOCX_INPUT_MD"

    return 0
}

# =============================================================================
# STEP 6: VERIFY PYTHON SCRIPTS
# =============================================================================

verify_python_scripts() {
    local step="$1"
    local total="$2"

    log_step "$step" "$total" "Verifying Python scripts"

    if [[ ! -d "$DOCX_SCRIPTS_DIR" ]]; then
        log_warning "Scripts directory not found: $DOCX_SCRIPTS_DIR"
        log_warning "Python scripts must be deployed before running pipeline"
        return 0
    fi

    local required_scripts=(
        "__init__.py"
        "md2docx.py"
        "h2d.py"
        "map_text.py"
        "map_list.py"
        "map_tbl.py"
        "map_inline.py"
    )

    local found=0
    local missing=0

    for script in "${required_scripts[@]}"; do
        if [[ -f "$DOCX_SCRIPTS_DIR/$script" ]]; then
            ((found++))
            log_debug "Found: $script"
        else
            ((missing++))
            log_debug "Missing: $script"
        fi
    done

    log_info "Python scripts status:"
    log_info "  Found: $found"
    log_info "  Missing: $missing"

    if [[ $missing -gt 0 ]]; then
        log_warning "Some Python scripts are missing"
        log_warning "ACCION REQUERIDA: Deploy Python scripts to: $DOCX_SCRIPTS_DIR"
        return 0
    fi

    # Validate Python syntax if all scripts exist
    if [[ $found -eq ${#required_scripts[@]} ]]; then
        log_info "Validating Python syntax..."

        local syntax_errors=0
        for script in "${required_scripts[@]}"; do
            if [[ "$script" == "__init__.py" ]]; then
                continue
            fi

            local syntax_check
            syntax_check=$("$DOCX_PYTHON" -m py_compile "$DOCX_SCRIPTS_DIR/$script" 2>&1)
            local exit_code=$?

            if [[ $exit_code -ne 0 ]]; then
                log_error "Syntax error in: $script"
                echo "$syntax_check" | head -5 >&2
                ((syntax_errors++))
            fi
        done

        if [[ $syntax_errors -eq 0 ]]; then
            log_success "All Python scripts have valid syntax"
        else
            log_error "Found $syntax_errors script(s) with syntax errors"
            return 1
        fi
    fi

    log_success "Python scripts verified"
    return 0
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    log_header "DOCX Pipeline Configuration"

    if is_component_functional "docx-pipeline"; then
        log_success "DOCX pipeline already configured"
        log_info "Skipping configuration (idempotence)"
        return 0
    fi

    log_info "DOCX pipeline not configured, proceeding with setup"

    create_directory_structure 1 6 || return 1
    configure_permissions 2 6 || return 1
    validate_template 3 6 || return 1
    validate_style_config 4 6 || return 1
    create_example_input 5 6 || return 1
    verify_python_scripts 6 6 || return 1

    if verify_docx_pipeline_configured; then
        log_success "DOCX pipeline configuration verified"
        mark_installation_state "docx-pipeline"

        log_info "Configuration details:"
        log_info "  Source dir: $DOCX_SRC_DIR"
        log_info "  Build dir: $DOCX_BUILD_DIR"
        log_info "  Template: $DOCX_TPL"
        log_info "  Style config: $DOCX_STYLE_YML"

        log_info "Next steps:"
        if [[ ! -f "$DOCX_TPL" ]] || [[ -f "${DOCX_TPL}.MISSING" ]]; then
            log_info "  1. Create Word template at: $DOCX_TPL"
        fi
        if [[ ! -f "$DOCX_MAIN_SCRIPT" ]]; then
            log_info "  2. Deploy Python scripts to: $DOCX_SCRIPTS_DIR"
        fi
        log_info "  3. Run: md2docx to generate DOCX files"

        return 0
    else
        log_warning "Configuration completed with warnings"
        log_warning "Some components may need manual setup"
        return 0
    fi
}

# =============================================================================
# EXECUTION
# =============================================================================

main "$@"
exit $?