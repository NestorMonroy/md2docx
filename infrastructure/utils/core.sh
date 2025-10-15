#!/usr/bin/env bash
# infrastructure/utils/core.sh - Core system functions

# =============================================================================
# GLOBAL STATE
# =============================================================================

ENVIRONMENT_LOADED="${ENVIRONMENT_LOADED:-false}"

# =============================================================================
# FALLBACK LOGGING (ALWAYS DEFINE FIRST)
# =============================================================================

_setup_fallback_logging() {
    log_info() {
        echo "[INFO] $*" >&2
    }

    log_success() {
        echo "[SUCCESS] $*" >&2
    }

    log_warning() {
        echo "[WARNING] $*" >&2
    }

    log_error() {
        echo "[ERROR] $*" >&2
    }

    log_debug() {
        if [[ "${LOG_LEVEL:-INFO}" == "DEBUG" ]]; then
            echo "[DEBUG] $*" >&2
        fi
    }

    log_header() {
        echo "" >&2
        echo "============================================================" >&2
        echo "  $*" >&2
        echo "============================================================" >&2
    }

    log_step() {
        echo "[STEP $1/$2] $3" >&2
    }

    export -f log_info log_success log_warning log_error log_debug log_header log_step
}

# Setup fallback logging IMMEDIATELY
_setup_fallback_logging

# =============================================================================
# LOAD PROJECT ENVIRONMENT
# =============================================================================

load_project_environment() {
    # If already loaded, skip re-initialization but functions are still available
    if [[ "$ENVIRONMENT_LOADED" == "true" ]]; then
        return 0
    fi

    local core_script_dir
    core_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    local core_project_root
    core_project_root="$(cd "$core_script_dir/../.." && pwd)"

    # Set PROJECT_ROOT only if not already set
    if [[ -z "${PROJECT_ROOT:-}" ]]; then
        PROJECT_ROOT="$core_project_root"
        export PROJECT_ROOT
    fi

    local vars_file="$PROJECT_ROOT/config/variables.sh"
    if [[ ! -f "$vars_file" ]]; then
        echo "CRITICAL: variables.sh not found at: $vars_file" >&2
        return 1
    fi

    if ! source "$vars_file"; then
        echo "CRITICAL: Failed to load variables.sh" >&2
        return 1
    fi

    # Try to load proper logging
    local log_file="$UTILS_DIR/logging.sh"
    if [[ -f "$log_file" ]]; then
        if source "$log_file"; then
            init_logging "$LOG_FILE" "$LOG_LEVEL"
        else
            echo "WARNING: Failed to load logging.sh, using fallback" >&2
        fi
    else
        echo "WARNING: logging.sh not found, using fallback" >&2
    fi

    # Load validation if available
    local valid_file="$UTILS_DIR/validation.sh"
    if [[ -f "$valid_file" ]]; then
        if ! source "$valid_file"; then
            log_warning "Failed to load validation.sh"
        fi
    else
        log_warning "validation.sh not found"
    fi

    # Validate required variables
    local required_vars=(
        "PROJECT_ROOT"
        "APP_STATE_DIR"
        "LOG_FILE"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            log_error "Required variable not set: $var"
            return 1
        fi
    done

    ENVIRONMENT_LOADED="true"
    export ENVIRONMENT_LOADED

    log_success "Environment loaded successfully"

    return 0
}

# =============================================================================
# COMPONENT VERIFICATION FUNCTIONS
# =============================================================================

# -----------------------------------------------------------------------------
# SYSTEM VERIFICATION
# -----------------------------------------------------------------------------

verify_system_functional() {
    local checks=(
        "command -v python3 >/dev/null 2>&1"
        "command -v pip3 >/dev/null 2>&1"
        "command -v dot >/dev/null 2>&1"
        "command -v pandoc >/dev/null 2>&1"
        "python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 6) else 1)' 2>/dev/null"
    )

    for check in "${checks[@]}"; do
        if ! eval "$check"; then
            log_debug "System check failed: $check"
            return 1
        fi
    done

    log_debug "System verification passed"
    return 0
}

# -----------------------------------------------------------------------------
# PYTM VERIFICATION
# -----------------------------------------------------------------------------

verify_pytm_functional() {
    local test_script="
import sys
try:
    from pytm import TM, Server, Dataflow, Actor
    tm = TM('test')
    server = Server('test_server')
    actor = Actor('test_actor')
    flow = Dataflow(actor, server, 'test_flow')
    sys.exit(0)
except ImportError as e:
    print(f'Import failed: {e}', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'pytm error: {e}', file=sys.stderr)
    sys.exit(1)
"

    local output
    output=$(python3 -c "$test_script" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_debug "pytm verification passed"
        return 0
    else
        log_debug "pytm verification failed: $output"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# TOMCAT VERIFICATION
# -----------------------------------------------------------------------------

verify_tomcat_functional() {
    # Check TOMCAT_HOME is set
    if [[ -z "${TOMCAT_HOME:-}" ]]; then
        log_debug "TOMCAT_HOME not set"
        return 1
    fi

    # Check Tomcat home directory exists
    if [[ ! -d "$TOMCAT_HOME" ]]; then
        log_debug "Tomcat home not found: $TOMCAT_HOME"
        return 1
    fi

    # Check catalina.sh exists
    if [[ ! -f "$TOMCAT_HOME/bin/catalina.sh" ]]; then
        log_debug "catalina.sh not found"
        return 1
    fi

    # Check catalina.sh is executable
    if [[ ! -x "$TOMCAT_HOME/bin/catalina.sh" ]]; then
        log_debug "catalina.sh not executable"
        return 1
    fi

    # Try to get version
    local version_output
    version_output=$("$TOMCAT_HOME/bin/catalina.sh" version 2>&1 || echo "")

    if ! echo "$version_output" | grep -q "Apache Tomcat"; then
        log_debug "Tomcat version check failed"
        return 1
    fi

    # Check if tomcat user exists
    if [[ -n "${TOMCAT_USER:-}" ]]; then
        if ! id "$TOMCAT_USER" &>/dev/null; then
            log_debug "Tomcat user not found: $TOMCAT_USER"
            return 1
        fi
    fi

    log_debug "Tomcat verification passed"
    return 0
}

# -----------------------------------------------------------------------------
# PLANTUML SERVER VERIFICATION
# -----------------------------------------------------------------------------

verify_plantuml_server_functional() {
    # Check TOMCAT_HOME is set
    if [[ -z "${TOMCAT_HOME:-}" ]]; then
        log_debug "TOMCAT_HOME not set"
        return 1
    fi

    # Check WAR file exists
    local war_file="$TOMCAT_HOME/webapps/plantuml.war"

    if [[ ! -f "$war_file" ]]; then
        log_debug "PlantUML WAR not found: $war_file"
        return 1
    fi

    # Check file size (should be > 1MB)
    local file_size
    file_size=$(stat -c%s "$war_file" 2>/dev/null || echo "0")

    if [[ $file_size -lt 1000000 ]]; then
        log_debug "PlantUML WAR file too small: $file_size bytes"
        return 1
    fi

    # Check if Graphviz is available
    if ! command -v dot >/dev/null 2>&1; then
        log_debug "Graphviz not found"
        return 1
    fi

    # Check systemd service exists
    if [[ -f "/etc/systemd/system/plantuml.service" ]]; then
        log_debug "PlantUML systemd service found"
    else
        log_debug "PlantUML systemd service not found (not critical)"
    fi

    log_debug "PlantUML server verification passed"
    return 0
}

# -----------------------------------------------------------------------------
# DOCX STACK VERIFICATION
# -----------------------------------------------------------------------------

verify_docx_stack_functional() {
    # Check virtualenv exists
    if [[ -z "${DOCX_VENV:-}" ]] || [[ ! -d "${DOCX_VENV}" ]]; then
        log_debug "DOCX virtualenv not found"
        return 1
    fi

    # Check Python executable
    if [[ -z "${DOCX_PYTHON:-}" ]] || [[ ! -f "${DOCX_PYTHON}" ]]; then
        log_debug "DOCX Python not found"
        return 1
    fi

    # Check required modules
    local modules=("markdown" "bs4" "docx" "yaml")
    for module in "${modules[@]}"; do
        if ! "${DOCX_PYTHON}" -c "import $module" 2>/dev/null; then
            log_debug "DOCX module not found: $module"
            return 1
        fi
    done

    log_debug "DOCX stack verification passed"
    return 0
}

# -----------------------------------------------------------------------------
# DOCX SCRIPTS VERIFICATION
# -----------------------------------------------------------------------------

verify_docx_scripts_functional() {
    # Check scripts directory
    if [[ -z "${DOCX_SCRIPTS_DIR:-}" ]] || [[ ! -d "${DOCX_SCRIPTS_DIR}" ]]; then
        log_debug "DOCX scripts directory not found"
        return 1
    fi

    # Check required scripts
    local scripts=("__init__.py" "md2docx.py" "h2d.py" "map_text.py" "map_list.py" "map_tbl.py" "map_inline.py")
    for script in "${scripts[@]}"; do
        if [[ ! -f "${DOCX_SCRIPTS_DIR}/${script}" ]]; then
            log_debug "DOCX script not found: $script"
            return 1
        fi
    done

    log_debug "DOCX scripts verification passed"
    return 0
}

# -----------------------------------------------------------------------------
# DOCX PIPELINE VERIFICATION
# -----------------------------------------------------------------------------

verify_docx_pipeline_functional() {
    # Check configuration files
    if [[ -z "${DOCX_STYLE_YML:-}" ]] || [[ ! -f "${DOCX_STYLE_YML}" ]]; then
        log_debug "DOCX style config not found"
        return 1
    fi

    # Check directories
    if [[ -z "${DOCX_SRC_DIR:-}" ]] || [[ ! -d "${DOCX_SRC_DIR}" ]]; then
        log_debug "DOCX source directory not found"
        return 1
    fi

    if [[ -z "${DOCX_BUILD_DIR:-}" ]] || [[ ! -d "${DOCX_BUILD_DIR}" ]]; then
        log_debug "DOCX build directory not found"
        return 1
    fi

    log_debug "DOCX pipeline verification passed"
    return 0
}

# -----------------------------------------------------------------------------
# DOCX CLI VERIFICATION
# -----------------------------------------------------------------------------

verify_docx_cli_functional() {
    # Check CLI exists
    if [[ ! -f "${PROJECT_ROOT}/bin/md2docx" ]]; then
        log_debug "DOCX CLI not found"
        return 1
    fi

    # Check executable
    if [[ ! -x "${PROJECT_ROOT}/bin/md2docx" ]]; then
        log_debug "DOCX CLI not executable"
        return 1
    fi

    log_debug "DOCX CLI verification passed"
    return 0
}

# =============================================================================
# COMPONENT FUNCTIONALITY CHECK
# =============================================================================

is_component_functional() {
    local component="$1"

    local state_file="$APP_STATE_DIR/${component}.installed"

    if [[ ! -f "$state_file" ]]; then
        log_debug "Component not marked as installed: $component"
        return 1
    fi

    log_debug "State file exists for: $component"

    # Map component names to verifier functions
    local verifier=""
    case "$component" in
        system)
            verifier="verify_system_functional"
            ;;
        pytm)
            verifier="verify_pytm_functional"
            ;;
        tomcat)
            verifier="verify_tomcat_functional"
            ;;
        plantuml-server)
            verifier="verify_plantuml_server_functional"
            ;;
        docx-stack)
            verifier="verify_docx_stack_functional"
            ;;
        docx-scripts)
            verifier="verify_docx_scripts_functional"
            ;;
        docx-pipeline)
            verifier="verify_docx_pipeline_functional"
            ;;
        docx-cli)
            verifier="verify_docx_cli_functional"
            ;;
        *)
            # For unknown components, try generic naming
            verifier="verify_${component}_functional"
            ;;
    esac

    if command -v "$verifier" >/dev/null 2>&1; then
        log_debug "Running functional verification for: $component"

        if "$verifier"; then
            log_success "Component is functional: $component"
            return 0
        else
            log_warning "Component installed but NOT functional: $component"
            log_warning "Auto-repair will trigger reinstallation"
            return 1
        fi
    else
        log_debug "No verifier function found for: $component"
        log_debug "Assuming functional based on state file"
        return 0
    fi
}

# =============================================================================
# MARK INSTALLATION STATE
# =============================================================================

mark_installation_state() {
    local component="$1"

    local state_file="$APP_STATE_DIR/${component}.installed"

    local state_dir
    state_dir="$(dirname "$state_file")"

    if [[ ! -d "$state_dir" ]]; then
        if ! mkdir -p "$state_dir" 2>/dev/null; then
            log_error "Failed to create state directory: $state_dir"
            return 1
        fi
        chmod 755 "$state_dir"
    fi

    local timestamp
    timestamp=$(date -Iseconds)

    local user
    user=$(whoami)

    local pid=$$

    {
        echo "Component: $component"
        echo "Status: installed"
        echo "Timestamp: $timestamp"
        echo "User: $user"
        echo "PID: $pid"
    } > "$state_file"

    if [[ $? -eq 0 ]]; then
        log_success "Marked as installed: $component"
        return 0
    else
        log_error "Failed to mark state: $component"
        return 1
    fi
}

# =============================================================================
# RUN INSTALL SCRIPT
# =============================================================================

run_install_script() {
    local script_path="$1"
    local description="${2:-installation script}"
    local timeout="${3:-${INSTALL_TIMEOUT:-1800}}"

    if [[ ! -f "$script_path" ]]; then
        log_error "Script not found: $script_path"
        return 1
    fi

    if [[ ! -r "$script_path" ]]; then
        log_error "Script not readable: $script_path"
        return 1
    fi

    log_info "Executing: $description"
    log_info "Script: $script_path"
    log_info "Timeout: $timeout seconds"

    local start_time
    start_time=$(date +%s)

    if timeout "$timeout" bash "$script_path"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_success "$description completed (${duration}s)"
        return 0
    else
        local exit_code=$?
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        if [[ $exit_code -eq 124 ]]; then
            log_error "$description TIMEOUT after ${timeout}s"
        else
            log_error "$description FAILED after ${duration}s (exit code: $exit_code)"
        fi

        return $exit_code
    fi
}

# =============================================================================
# CREATE PROJECT DIRECTORIES
# =============================================================================

create_project_directories() {
    local dir_list=(
        "$APP_BASE_DIR"
        "$APP_LOG_DIR"
        "$APP_STATE_DIR"
        "$APP_CACHE_DIR"
        "$MODELS_DIR"
        "$OUTPUT_DIR"
        "$DIAGRAMS_DIR"
        "$REPORTS_DIR"
        "$TEMPLATES_DIR"
    )

    local created=0
    local existing=0
    local failed=0

    for dir in "${dir_list[@]}"; do
        if [[ -d "$dir" ]]; then
            log_debug "Already exists: $dir"
            ((existing++))
        else
            if mkdir -p "$dir" 2>/dev/null; then
                log_debug "Created: $dir"
                chmod 755 "$dir" 2>/dev/null || true
                ((created++))
            else
                log_error "Failed to create: $dir"
                ((failed++))
            fi
        fi
    done

    log_info "Directory structure summary:"
    log_info "  Created: $created"
    log_info "  Existing: $existing"

    if [[ $failed -gt 0 ]]; then
        log_info "  Failed: $failed"
    fi

    if [[ $failed -gt 0 ]]; then
        return 1
    else
        log_success "Project structure verified"
        return 0
    fi
}

# =============================================================================
# VERIFY ENVIRONMENT READY
# =============================================================================

verify_environment_ready() {
    local passed=0
    local total=0

    ((total++))
    if [[ "$ENVIRONMENT_LOADED" == "true" ]]; then
        log_debug "Check: Environment loaded"
        ((passed++))
    else
        log_error "Check FAILED: Environment not loaded"
    fi

    ((total++))
    local critical_dirs=(
        "$APP_STATE_DIR"
        "$PROJECT_ROOT"
    )

    local all_exist=true
    for dir in "${critical_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            all_exist=false
            break
        fi
    done

    if $all_exist; then
        log_debug "Check: Critical directories exist"
        ((passed++))
    else
        log_error "Check FAILED: Critical directories missing"
    fi

    ((total++))
    if command -v log_info >/dev/null 2>&1; then
        log_debug "Check: Logging functions available"
        ((passed++))
    else
        echo "Check FAILED: Logging not available" >&2
    fi

    if [[ $passed -eq $total ]]; then
        log_success "Environment verification passed ($passed/$total)"
        return 0
    else
        log_error "Environment verification FAILED ($passed/$total)"
        return 1
    fi
}

# =============================================================================
# MARK AS LOADED
# =============================================================================

CORE_LOADED="true"
export CORE_LOADED