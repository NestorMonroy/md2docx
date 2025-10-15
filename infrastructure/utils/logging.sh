#!/usr/bin/env bash
# utils/logging.sh - Sistema Completo de Logging con Colores
# Proporciona logging dual: consola con colores + archivo con timestamps

# =============================================================================
# CONFIGURACIÓN DE COLORES Y FORMATO
# =============================================================================

# Colores para consola (solo si está disponible)
if [[ -t 1 ]]; then
    readonly COLOR_RED='\033[0;31m'
    readonly COLOR_GREEN='\033[0;32m'
    readonly COLOR_YELLOW='\033[1;33m'
    readonly COLOR_BLUE='\033[0;34m'
    readonly COLOR_PURPLE='\033[0;35m'
    readonly COLOR_CYAN='\033[0;36m'
    readonly COLOR_WHITE='\033[1;37m'
    readonly COLOR_GRAY='\033[0;37m'
    readonly COLOR_RESET='\033[0m'
    readonly COLOR_BOLD='\033[1m'
else
    readonly COLOR_RED=''
    readonly COLOR_GREEN=''
    readonly COLOR_YELLOW=''
    readonly COLOR_BLUE=''
    readonly COLOR_PURPLE=''
    readonly COLOR_CYAN=''
    readonly COLOR_WHITE=''
    readonly COLOR_GRAY=''
    readonly COLOR_RESET=''
    readonly COLOR_BOLD=''
fi

# Configuración de logging
LOG_LEVEL=${LOG_LEVEL:-"INFO"}
LOG_TO_FILE=${LOG_TO_FILE:-true}
LOG_TO_CONSOLE=${LOG_TO_CONSOLE:-true}

# =============================================================================
# FUNCIONES DE TIMESTAMP Y FORMATO
# =============================================================================

# Obtiene timestamp formateado
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Obtiene timestamp para nombres de archivo
get_timestamp_filename() {
    date '+%Y%m%d_%H%M%S'
}

# Formatea mensaje para archivo (sin colores)
format_log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(get_timestamp)
    echo "[$timestamp] [$level] $message"
}

# Escribe a archivo de log si está configurado
write_to_logfile() {
    local message="$1"

    if [[ "$LOG_TO_FILE" == "true" ]] && [[ -n "$LOG_FILE" ]]; then
        # Crear directorio del log si no existe
        local log_dir
        log_dir=$(dirname "$LOG_FILE")
        [[ ! -d "$log_dir" ]] && mkdir -p "$log_dir" 2>/dev/null

        # Escribir al archivo
        echo "$message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# =============================================================================
# FUNCIONES DE LOGGING PRINCIPALES
# =============================================================================

# Logging de información general
log_info() {
    local message="$1"
    local formatted_message
    formatted_message=$(format_log_message "INFO" "$message")

    # Consola con colores
    if [[ "$LOG_TO_CONSOLE" == "true" ]]; then
        echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $message"
    fi

    # Archivo sin colores
    write_to_logfile "$formatted_message"
}

# Logging de éxito
log_success() {
    local message="$1"
    local formatted_message
    formatted_message=$(format_log_message "SUCCESS" "$message")

    # Consola con colores
    if [[ "$LOG_TO_CONSOLE" == "true" ]]; then
        echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $message"
    fi

    # Archivo sin colores
    write_to_logfile "$formatted_message"
}

# Logging de advertencias
log_warning() {
    local message="$1"
    local formatted_message
    formatted_message=$(format_log_message "WARNING" "$message")

    # Consola con colores (stderr)
    if [[ "$LOG_TO_CONSOLE" == "true" ]]; then
        echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $message" >&2
    fi

    # Archivo sin colores
    write_to_logfile "$formatted_message"
}

# Logging de errores
log_error() {
    local message="$1"
    local formatted_message
    formatted_message=$(format_log_message "ERROR" "$message")

    # Consola con colores (stderr)
    if [[ "$LOG_TO_CONSOLE" == "true" ]]; then
        echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $message" >&2
    fi

    # Archivo sin colores
    write_to_logfile "$formatted_message"
}

# Logging de pasos del proceso
log_step() {
    local step_number="$1"
    local total_steps="$2"
    local message="$3"
    local formatted_message
    formatted_message=$(format_log_message "STEP" "[$step_number/$total_steps] $message")

    # Consola con colores
    if [[ "$LOG_TO_CONSOLE" == "true" ]]; then
        echo -e "${COLOR_CYAN}[STEP $step_number/$total_steps]${COLOR_RESET} $message"
    fi

    # Archivo sin colores
    write_to_logfile "$formatted_message"
}

# Logging de debug (solo si LOG_LEVEL=DEBUG)
log_debug() {
    [[ "$LOG_LEVEL" != "DEBUG" ]] && return 0

    local message="$1"
    local formatted_message
    formatted_message=$(format_log_message "DEBUG" "$message")

    # Consola con colores
    if [[ "$LOG_TO_CONSOLE" == "true" ]]; then
        echo -e "${COLOR_GRAY}[DEBUG]${COLOR_RESET} $message"
    fi

    # Archivo sin colores
    write_to_logfile "$formatted_message"
}

# =============================================================================
# FUNCIONES DE FORMATO VISUAL
# =============================================================================

# Crea header visual para secciones
log_header() {
    local title="$1"
    local width=${2:-60}
    local char=${3:-"="}

    # Crear línea de separación
    local separator
    separator=$(printf "%.${width}s" "$(printf "%*s" "$width" | tr ' ' "$char")")

    local header_message="$separator
$title
$separator"

    local formatted_message
    formatted_message=$(format_log_message "HEADER" "$title")

    # Consola con colores
    if [[ "$LOG_TO_CONSOLE" == "true" ]]; then
        echo -e "${COLOR_BOLD}${COLOR_WHITE}$header_message${COLOR_RESET}"
    fi

    # Archivo sin colores
    write_to_logfile "$formatted_message"
}

# Crea subheader para subsecciones
log_subheader() {
    local title="$1"
    local width=${2:-40}
    local char=${3:-"-"}

    local separator
    separator=$(printf "%.${width}s" "$(printf "%*s" "$width" | tr ' ' "$char")")

    local formatted_message
    formatted_message=$(format_log_message "SUBHEADER" "$title")

    # Consola con colores
    if [[ "$LOG_TO_CONSOLE" == "true" ]]; then
        echo -e "${COLOR_PURPLE}$separator${COLOR_RESET}"
        echo -e "${COLOR_PURPLE}$title${COLOR_RESET}"
        echo -e "${COLOR_PURPLE}$separator${COLOR_RESET}"
    fi

    # Archivo sin colores
    write_to_logfile "$formatted_message"
}

# =============================================================================
# FUNCIONES DE UTILIDAD
# =============================================================================

# Error fatal que termina el script
die() {
    local message="$1"
    local exit_code="${2:-1}"

    log_error "FATAL: $message"
    log_error "Terminando ejecución con código $exit_code"

    exit "$exit_code"
}

# Ejecuta comando con logging automático
safe_execute() {
    local description="$1"
    shift
    local command=("$@")

    log_info "Ejecutando: $description"
    log_debug "Comando: ${command[*]}"

    local start_time
    start_time=$(date +%s)

    if "${command[@]}"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "$description completado (${duration}s)"
        return 0
    else
        local exit_code=$?
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_error "$description falló después de ${duration}s (código: $exit_code)"
        return $exit_code
    fi
}

# Ejecuta comando con logging silencioso (solo errores)
silent_execute() {
    local description="$1"
    shift
    local command=("$@")

    log_debug "Ejecutando silenciosamente: $description"

    if "${command[@]}" >/dev/null 2>&1; then
        log_debug "$description completado silenciosamente"
        return 0
    else
        local exit_code=$?
        log_error "$description falló (código: $exit_code)"
        return $exit_code
    fi
}

# =============================================================================
# FUNCIONES DE CONFIGURACIÓN
# =============================================================================

# Inicializa el sistema de logging
init_logging() {
    local log_file="$1"
    local log_level="${2:-INFO}"

    # Configurar variables globales
    export LOG_FILE="$log_file"
    export LOG_LEVEL="$log_level"

    # Crear directorio de logs si no existe
    if [[ -n "$log_file" ]]; then
        local log_dir
        log_dir=$(dirname "$log_file")
        mkdir -p "$log_dir" 2>/dev/null || {
            echo "ERROR: No se puede crear directorio de logs: $log_dir" >&2
            return 1
        }

        # Escribir mensaje inicial
        log_info "=== Iniciando logging en $log_file ==="
        log_info "Nivel de log: $log_level"
        log_info "PID del proceso: $$"
        log_info "Usuario: $(whoami)"
        log_info "Fecha: $(date)"
    fi

    return 0
}

# Establece el nivel de logging
set_log_level() {
    local level="$1"

    case "$level" in
        "DEBUG"|"INFO"|"WARNING"|"ERROR")
            export LOG_LEVEL="$level"
            log_info "Nivel de logging cambiado a: $level"
            ;;
        *)
            log_warning "Nivel de logging inválido: $level. Manteniendo: $LOG_LEVEL"
            return 1
            ;;
    esac
}

# Habilita/deshabilita logging a archivo
toggle_file_logging() {
    local enable="${1:-toggle}"

    case "$enable" in
        "true"|"on"|"enable")
            export LOG_TO_FILE=true
            log_info "Logging a archivo habilitado"
            ;;
        "false"|"off"|"disable")
            export LOG_TO_FILE=false
            log_info "Logging a archivo deshabilitado"
            ;;
        "toggle")
            if [[ "$LOG_TO_FILE" == "true" ]]; then
                export LOG_TO_FILE=false
                echo "[INFO] Logging a archivo deshabilitado"
            else
                export LOG_TO_FILE=true
                echo "[INFO] Logging a archivo habilitado"
            fi
            ;;
        *)
            log_warning "Opción inválida para toggle_file_logging: $enable"
            return 1
            ;;
    esac
}

# Habilita/deshabilita logging a consola
toggle_console_logging() {
    local enable="${1:-toggle}"

    case "$enable" in
        "true"|"on"|"enable")
            export LOG_TO_CONSOLE=true
            ;;
        "false"|"off"|"disable")
            export LOG_TO_CONSOLE=false
            ;;
        "toggle")
            if [[ "$LOG_TO_CONSOLE" == "true" ]]; then
                export LOG_TO_CONSOLE=false
            else
                export LOG_TO_CONSOLE=true
            fi
            ;;
        *)
            [[ "$LOG_TO_CONSOLE" == "true" ]] && log_warning "Opción inválida para toggle_console_logging: $enable"
            return 1
            ;;
    esac
}

# =============================================================================
# FUNCIONES DE LIMPIEZA
# =============================================================================

# Rota logs por tamaño
rotate_log_if_needed() {
    local log_file="${1:-$LOG_FILE}"
    local max_size_mb="${2:-10}"

    [[ -z "$log_file" ]] && return 0
    [[ ! -f "$log_file" ]] && return 0

    local file_size_mb
    file_size_mb=$(du -m "$log_file" | cut -f1)

    if (( file_size_mb > max_size_mb )); then
        local timestamp
        timestamp=$(get_timestamp_filename)
        local rotated_name="${log_file}.${timestamp}"

        log_info "Rotando log: $log_file -> $rotated_name"
        mv "$log_file" "$rotated_name" 2>/dev/null || {
            log_warning "No se pudo rotar el archivo de log"
            return 1
        }

        # Comprimir log rotado
        gzip "$rotated_name" 2>/dev/null && {
            log_info "Log rotado comprimido: ${rotated_name}.gz"
        }
    fi
}

# Limpia logs antiguos
cleanup_old_logs() {
    local log_dir="${1:-$(dirname "$LOG_FILE")}"
    local days="${2:-7}"

    [[ -z "$log_dir" ]] && return 0
    [[ ! -d "$log_dir" ]] && return 0

    log_info "Limpiando logs antiguos (>${days} días) en $log_dir"

    find "$log_dir" -name "*.log.*" -type f -mtime "+${days}" -delete 2>/dev/null && {
        log_info "Logs antiguos eliminados exitosamente"
    } || {
        log_warning "Problema al limpiar logs antiguos"
    }
}

# =============================================================================
# AUTO-EJECUCIÓN Y PRUEBAS
# =============================================================================

# Si el script se ejecuta directamente, mostrar ejemplos
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== Sistema de Logging - Prueba de Funciones ==="

    # Inicializar logging
    init_logging "/tmp/test_logging.log" "DEBUG"

    # Pruebas de las funciones
    log_header "PRUEBA DEL SISTEMA DE LOGGING"
    log_info "Esta es una prueba de información"
    log_success "Esta es una prueba de éxito"
    log_warning "Esta es una prueba de advertencia"
    log_error "Esta es una prueba de error"
    log_debug "Esta es una prueba de debug"

    log_subheader "Prueba de Pasos"
    log_step 1 3 "Primer paso del proceso"
    log_step 2 3 "Segundo paso del proceso"
    log_step 3 3 "Tercer paso del proceso"

    log_subheader "Prueba de Ejecución Segura"
    safe_execute "Listar directorio actual" ls -la
    safe_execute "Comando que falla" false || log_info "El comando falló como se esperaba"

    log_success "Prueba del sistema de logging completada"
    echo "Log guardado en: /tmp/test_logging.log"
fi