#!/usr/bin/env bash
# utils/validation.sh - Validaciones Esenciales del Entorno
# Proporciona validaciones robustas para variables, OS, recursos y conectividad

# =============================================================================
# VALIDACIONES DE VARIABLES
# =============================================================================

# Valida que una variable esté definida y no esté vacía
validate_variable() {
    local var_name="$1"
    local var_value="${!var_name}"

    if [[ -z "$var_value" ]]; then
        log_error "Variable requerida no definida o vacía: $var_name"
        return 1
    fi

    log_debug "Variable válida: $var_name = '$var_value'"
    return 0
}

# Valida múltiples variables requeridas
validate_required_variables() {
    local variables=("$@")
    local failed_vars=()

    log_info "Validando variables requeridas..."

    for var in "${variables[@]}"; do
        if ! validate_variable "$var"; then
            failed_vars+=("$var")
        fi
    done

    if [[ ${#failed_vars[@]} -gt 0 ]]; then
        log_error "Variables requeridas faltantes: ${failed_vars[*]}"
        return 1
    fi

    log_success "Todas las variables requeridas están definidas (${#variables[@]} variables)"
    return 0
}

# Valida que una variable sea un número
validate_numeric() {
    local var_name="$1"
    local var_value="${!var_name}"

    if ! [[ "$var_value" =~ ^[0-9]+$ ]]; then
        log_error "Variable $var_name debe ser numérica: '$var_value'"
        return 1
    fi

    log_debug "Variable numérica válida: $var_name = $var_value"
    return 0
}

# Valida que una variable sea un directorio válido
validate_directory() {
    local var_name="$1"
    local dir_path="${!var_name}"

    if [[ ! -d "$dir_path" ]]; then
        log_error "Directorio no existe: $var_name = '$dir_path'"
        return 1
    fi

    log_debug "Directorio válido: $var_name = '$dir_path'"
    return 0
}

# Valida que una variable sea una IP válida
validate_ip_address() {
    local var_name="$1"
    local ip_addr="${!var_name}"

    local ip_regex='^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'

    if ! [[ "$ip_addr" =~ $ip_regex ]]; then
        log_error "Dirección IP inválida: $var_name = '$ip_addr'"
        return 1
    fi

    log_debug "IP válida: $var_name = '$ip_addr'"
    return 0
}

# =============================================================================
# VALIDACIONES DEL SISTEMA OPERATIVO
# =============================================================================

# Verifica que el sistema operativo sea compatible
validate_operating_system() {
    log_info "Validando sistema operativo..."

    local os_name
    os_name=$(uname -s)

    if [[ "$os_name" != "Linux" ]]; then
        log_error "Sistema operativo no compatible: $os_name (se requiere Linux)"
        return 1
    fi

    # Verificar distribución
    local distro=""
    if [[ -f /etc/os-release ]]; then
        distro=$(grep '^NAME=' /etc/os-release | cut -d'"' -f2)
        log_info "Distribución detectada: $distro"
    else
        log_warning "No se pudo detectar la distribución (/etc/os-release no encontrado)"
    fi

    # Verificar arquitectura
    local arch
    arch=$(uname -m)
    log_info "Arquitectura: $arch"

    # Verificar versión del kernel
    local kernel_version
    kernel_version=$(uname -r)
    log_info "Versión del kernel: $kernel_version"

    log_success "Sistema operativo compatible: Linux $kernel_version"
    return 0
}

# Verifica que el usuario tenga privilegios de root
validate_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root (sudo)"
        log_info "Intente: sudo $0"
        return 1
    fi

    log_debug "Privilegios de root confirmados (UID: $EUID)"
    return 0
}

# Verifica la disponibilidad de comandos esenciales
validate_required_commands() {
    local commands=("$@")
    local missing_commands=()

    log_info "Validando comandos requeridos..."

    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
            log_error "Comando no encontrado: $cmd"
        else
            log_debug "Comando disponible: $cmd"
        fi
    done

    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Comandos faltantes: ${missing_commands[*]}"
        log_info "ACCION REQUERIDA: Instalar paquetes faltantes"
        return 1
    fi

    log_success "Todos los comandos requeridos están disponibles (${#commands[@]} comandos)"
    return 0
}

# =============================================================================
# VALIDACIONES DE RECURSOS DEL SISTEMA
# =============================================================================

# Verifica que haya suficiente memoria RAM
validate_memory() {
    local min_memory_mb="${1:-$MIN_RAM_MB}"

    [[ -z "$min_memory_mb" ]] && {
        log_warning "Mínimo de RAM no especificado, omitiendo validación"
        return 0
    }

    log_info "Validando memoria RAM (mínimo: ${min_memory_mb}MB)..."

    local available_memory_kb
    available_memory_kb=$(grep '^MemAvailable:' /proc/meminfo | awk '{print $2}' 2>/dev/null)

    if [[ -z "$available_memory_kb" ]]; then
        # Fallback para sistemas sin MemAvailable
        available_memory_kb=$(grep '^MemFree:' /proc/meminfo | awk '{print $2}' 2>/dev/null)
    fi

    if [[ -z "$available_memory_kb" ]]; then
        log_error "No se pudo determinar la memoria disponible"
        return 1
    fi

    local available_memory_mb=$((available_memory_kb / 1024))

    if (( available_memory_mb < min_memory_mb )); then
        log_error "Memoria insuficiente: ${available_memory_mb}MB disponible, ${min_memory_mb}MB requerido"
        return 1
    fi

    log_success "Memoria suficiente: ${available_memory_mb}MB disponible"
    return 0
}

# Verifica que haya suficiente espacio en disco
validate_disk_space() {
    local path="${1:-/}"
    local min_space_mb="${2:-$MIN_DISK_MB}"

    [[ -z "$min_space_mb" ]] && {
        log_warning "Mínimo de espacio en disco no especificado, omitiendo validación"
        return 0
    }

    log_info "Validando espacio en disco en $path (mínimo: ${min_space_mb}MB)..."

    local available_space_kb
    available_space_kb=$(df "$path" | awk 'NR==2 {print $4}' 2>/dev/null)

    if [[ -z "$available_space_kb" ]]; then
        log_error "No se pudo determinar el espacio disponible en $path"
        return 1
    fi

    local available_space_mb=$((available_space_kb / 1024))

    if (( available_space_mb < min_space_mb )); then
        log_error "Espacio insuficiente en $path: ${available_space_mb}MB disponible, ${min_space_mb}MB requerido"
        return 1
    fi

    log_success "Espacio suficiente en $path: ${available_space_mb}MB disponible"
    return 0
}

# Verifica el número de CPUs disponibles
validate_cpu_cores() {
    local min_cores="${1:-$MIN_CPU_CORES}"

    [[ -z "$min_cores" ]] && {
        log_warning "Mínimo de CPUs no especificado, omitiendo validación"
        return 0
    }

    log_info "Validando CPUs disponibles (mínimo: $min_cores)..."

    local available_cores
    available_cores=$(nproc 2>/dev/null)

    if [[ -z "$available_cores" ]]; then
        # Fallback
        available_cores=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null)
    fi

    if [[ -z "$available_cores" ]]; then
        log_error "No se pudo determinar el número de CPUs"
        return 1
    fi

    if (( available_cores < min_cores )); then
        log_error "CPUs insuficientes: $available_cores disponibles, $min_cores requeridas"
        return 1
    fi

    log_success "CPUs suficientes: $available_cores disponibles"
    return 0
}

# =============================================================================
# VALIDACIONES DE CONECTIVIDAD
# =============================================================================

# Espera a que un puerto esté disponible
wait_for_port() {
    local host="${1:-localhost}"
    local port="$2"
    local timeout="${3:-60}"
    local description="${4:-puerto $port}"

    [[ -z "$port" ]] && {
        log_error "Puerto no especificado para wait_for_port"
        return 1
    }

    log_info "Esperando conectividad en $description ($host:$port)..."

    local elapsed=0
    local sleep_interval=2

    while (( elapsed < timeout )); do
        if nc -z "$host" "$port" 2>/dev/null; then
            log_success "$description está disponible ($host:$port)"
            return 0
        fi

        sleep $sleep_interval
        elapsed=$((elapsed + sleep_interval))

        if (( elapsed % 10 == 0 )); then
            log_info "Esperando $description... (${elapsed}s/${timeout}s)"
        fi
    done

    log_error "Timeout esperando $description ($host:$port) después de ${timeout}s"
    return 1
}

# Espera a que un endpoint HTTP responda
wait_for_http() {
    local url="$1"
    local timeout="${2:-60}"
    local expected_code="${3:-200}"
    local description="${4:-endpoint HTTP}"

    [[ -z "$url" ]] && {
        log_error "URL no especificada para wait_for_http"
        return 1
    }

    log_info "Esperando respuesta HTTP en $description ($url)..."

    local elapsed=0
    local sleep_interval=3

    while (( elapsed < timeout )); do
        local response_code
        response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)

        if [[ "$response_code" == "$expected_code" ]]; then
            log_success "$description está disponible (HTTP $response_code)"
            return 0
        fi

        sleep $sleep_interval
        elapsed=$((elapsed + sleep_interval))

        if (( elapsed % 15 == 0 )); then
            log_info "Esperando $description... (${elapsed}s/${timeout}s, último código: ${response_code:-N/A})"
        fi
    done

    log_error "Timeout esperando $description ($url) después de ${timeout}s"
    return 1
}

# Verifica conectividad de red básica
validate_network_connectivity() {
    log_info "Validando conectividad de red..."

    # Verificar interfaz de red local
    if ! ip link show 2>/dev/null | grep -q "state UP"; then
        log_error "No hay interfaces de red activas"
        return 1
    fi

    # Verificar conectividad externa (opcional)
    if command -v ping >/dev/null 2>&1; then
        if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
            log_success "Conectividad externa verificada"
        else
            log_warning "Sin conectividad externa (continuando)"
        fi
    fi

    log_success "Conectividad de red básica verificada"
    return 0
}

# =============================================================================
# VALIDACIONES DE SERVICIOS
# =============================================================================

# Verifica que un servicio esté corriendo
validate_service_running() {
    local service_name="$1"

    [[ -z "$service_name" ]] && {
        log_error "Nombre de servicio no especificado"
        return 1
    }

    log_info "Validando servicio: $service_name"

    if systemctl is-active "$service_name" >/dev/null 2>&1; then
        log_success "Servicio $service_name está activo"
        return 0
    else
        log_error "Servicio $service_name no está activo"
        return 1
    fi
}

# Verifica que un servicio esté habilitado para inicio automático
validate_service_enabled() {
    local service_name="$1"

    [[ -z "$service_name" ]] && {
        log_error "Nombre de servicio no especificado"
        return 1
    }

    log_info "Validando habilitación de servicio: $service_name"

    if systemctl is-enabled "$service_name" >/dev/null 2>&1; then
        log_success "Servicio $service_name está habilitado"
        return 0
    else
        log_error "Servicio $service_name no está habilitado"
        return 1
    fi
}

# =============================================================================
# VALIDACIÓN BÁSICA DEL ENTORNO
# =============================================================================

# Función principal que ejecuta validaciones básicas del entorno
validate_basic_environment() {
    local validation_errors=0

    log_header "VALIDACIÓN DEL ENTORNO BÁSICO"

    # Validaciones obligatorias
    validate_operating_system || ((validation_errors++))
    validate_root_privileges || ((validation_errors++))

    # Validaciones de comandos básicos
    validate_required_commands "curl" "wget" "nc" "systemctl" "ip" || ((validation_errors++))

    # Validaciones de recursos (si están definidas)
    validate_memory || ((validation_errors++))
    validate_disk_space "/" || ((validation_errors++))
    validate_cpu_cores || ((validation_errors++))

    # Validación de conectividad
    validate_network_connectivity || ((validation_errors++))

    # Resultado final
    if (( validation_errors == 0 )); then
        log_success "Todas las validaciones del entorno básico pasaron exitosamente"
        return 0
    else
        log_error "Falló la validación del entorno básico ($validation_errors errores)"
        return 1
    fi
}

# =============================================================================
# FUNCIONES DE UTILIDAD
# =============================================================================

# Valida una lista de puertos que deben estar libres
validate_ports_available() {
    local ports=("$@")
    local busy_ports=()

    log_info "Validando disponibilidad de puertos..."

    for port in "${ports[@]}"; do
        if nc -z localhost "$port" 2>/dev/null; then
            busy_ports+=("$port")
            log_error "Puerto $port ya está en uso"
        else
            log_debug "Puerto $port está disponible"
        fi
    done

    if [[ ${#busy_ports[@]} -gt 0 ]]; then
        log_error "Puertos ocupados: ${busy_ports[*]}"
        return 1
    fi

    log_success "Todos los puertos están disponibles (${#ports[@]} puertos)"
    return 0
}

# Valida que los archivos de configuración existan
validate_config_files() {
    local files=("$@")
    local missing_files=()

    log_info "Validando archivos de configuración..."

    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
            log_error "Archivo de configuración no encontrado: $file"
        else
            log_debug "Archivo de configuración encontrado: $file"
        fi
    done

    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Archivos de configuración faltantes: ${missing_files[*]}"
        return 1
    fi

    log_success "Todos los archivos de configuración están presentes (${#files[@]} archivos)"
    return 0
}

# =============================================================================
# AUTO-EJECUCIÓN Y PRUEBAS
# =============================================================================

# Si el script se ejecuta directamente, ejecutar validaciones básicas
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== Sistema de Validación - Prueba Básica ==="

    # Cargar sistema de logging para las pruebas
    if [[ -f "utils/logging.sh" ]]; then
        source "utils/logging.sh"
        init_logging "/tmp/test_validation.log" "DEBUG"
    else
        # Funciones básicas de logging si no está disponible
        log_info() { echo "[INFO] $1"; }
        log_error() { echo "[ERROR] $1" >&2; }
        log_success() { echo "[SUCCESS] $1"; }
        log_warning() { echo "[WARNING] $1" >&2; }
        log_debug() { echo "[DEBUG] $1"; }
        log_header() { echo "=== $1 ==="; }
    fi

    # Ejecutar validaciones básicas
    if validate_basic_environment; then
        echo "=== Validaciones básicas completadas exitosamente ==="
        exit 0
    else
        echo "=== Falló la validación básica del entorno ==="
        exit 1
    fi
fi