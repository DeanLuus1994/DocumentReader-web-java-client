#!/bin/bash
#===============================================================================
# DocumentReader Web Java Client - Development Container Entrypoint
#===============================================================================
# Original Author: Regula Forensics Inc. (base repository)
# Dev Container Implementation: Dean Luus
# Email: dean.luus@jdconsulting.com
# GitHub: https://github.com/DeanLuus
# Date: 2025/03/27
# Last updated: 2025/03/27
#===============================================================================

# Set bash options for better error reporting but avoid pipeline failure
set -o errtrace  # Make trap ERR inherit through function calls
set -o functrace # Make trap DEBUG inherit through function calls
set -o pipefail  # Return value of pipeline is value of last non-zero command
# set -o xtrace  # Uncomment for maximum debugging (shows each command)

#===============================================================================
# CONSTANTS AND TYPE DECLARATIONS
#===============================================================================

# Core settings
readonly DEBUG=${DEBUG:-true}
readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_VERSION="1.0.0"
readonly START_TIME=$(date +%s)
readonly HOSTNAME=$(hostname)
readonly PID=$$
readonly SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
readonly CONTAINER_ID=$(hostname)

# Setup error logging file
readonly LOG_DIR="/tmp/devcontainer-logs"
readonly LOG_FILE="${LOG_DIR}/entrypoint-$(date +%Y%m%d-%H%M%S).log"
readonly RECOVERY_SCRIPT="${LOG_DIR}/recovery-script.sh"
mkdir -p "${LOG_DIR}"
touch "${LOG_FILE}"
chmod 644 "${LOG_FILE}"

# Source environment variables with fallback mechanism
if [ -f "/workspaces/DocumentReader-web-java-client/.devcontainer/.env" ]; then
    source "/workspaces/DocumentReader-web-java-client/.devcontainer/.env"
elif [ -f "${SCRIPT_DIR}/.env" ]; then
    source "${SCRIPT_DIR}/.env"
fi

# Critical environment variables with defaults
: "${PROJECT_DIR:=/workspaces/DocumentReader-web-java-client}"
: "${SETUP_FLAG_FILE:=/tmp/needs_setup}"
: "${DOCKER_SOCKET:=/var/run/docker.sock}"
: "${OPENAPI_GENERATOR_VERSION:=v5.0.0-beta2}"
: "${RESOURCES_DIR:=${PROJECT_DIR}/example/src/main/resources}"
: "${OPENAPI_DIR:=${PROJECT_DIR}/openapi}"
: "${CONFIG_FILE:=${PROJECT_DIR}/client/java-generator-config.json}"
: "${TEMPLATES_DIR:=${PROJECT_DIR}/client/generator-templates}"
: "${CLIENT_OUTPUT_DIR:=${PROJECT_DIR}/client}"
: "${MAX_RETRIES:=3}"
: "${RETRY_DELAY:=5}"
: "${TIMEOUT:=60}"
: "${CHECK_INTERVAL:=5}"
: "${HEALTH_FILE:=/tmp/container-health}"

# Return code definitions for operations
readonly RC_SUCCESS=0
readonly RC_ERROR=1
readonly RC_WARN=2
readonly RC_CRITICAL=10
readonly RC_TIMEOUT=124
readonly RC_PERMISSION=126
readonly RC_NOT_FOUND=127

# Log levels with numeric values for filtering
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_CRITICAL=4
readonly LOG_LEVEL_SILENT=9

# Set current log level based on DEBUG setting
readonly CURRENT_LOG_LEVEL=$([ "$DEBUG" = true ] && echo $LOG_LEVEL_DEBUG || echo $LOG_LEVEL_INFO)

# Log level display names
readonly LOG_DEBUG="DEBUG"
readonly LOG_INFO="INFO"
readonly LOG_WARN="WARN"
readonly LOG_ERROR="ERROR"
readonly LOG_CRITICAL="CRITICAL"

# Operation types for better log categorization
readonly OP_INIT="INIT"
readonly OP_CONFIG="CONFIG"
readonly OP_PERMISSIONS="PERMISSIONS"
readonly OP_DIRECTORY="DIRECTORY"
readonly OP_DOCKER_SOCKET="DOCKER_SOCKET"
readonly OP_OPENAPI_GEN="OPENAPI_GENERATOR"
readonly OP_CODE_FORMAT="CODE_FORMAT"
readonly OP_BUILD="BUILD"
readonly OP_SETUP_BEGIN="SETUP_BEGIN"
readonly OP_SETUP_COMPLETE="SETUP_COMPLETE"
readonly OP_CONTAINER_READY="CONTAINER_READY"
readonly OP_EXEC="EXEC"
readonly OP_WSL_CHECK="WSL_CHECK"
readonly OP_DEBUG="DEBUG"
readonly OP_VALIDATION="VALIDATION"
readonly OP_CLEANUP="CLEANUP"
readonly OP_HEALTH="HEALTH"
readonly OP_RECOVERY="RECOVERY"

#===============================================================================
# CORE UTILITY FUNCTIONS
#===============================================================================

# Enhanced logging function with timestamp, log levels, and file output
log() {
    local level="$1"
    local operation="$2"
    local message="$3"
    local level_num
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Convert level name to numeric level
    case "$level" in
        "$LOG_DEBUG")   level_num=$LOG_LEVEL_DEBUG ;;
        "$LOG_INFO")    level_num=$LOG_LEVEL_INFO ;;
        "$LOG_WARN")    level_num=$LOG_LEVEL_WARN ;;
        "$LOG_ERROR")   level_num=$LOG_LEVEL_ERROR ;;
        "$LOG_CRITICAL") level_num=$LOG_LEVEL_CRITICAL ;;
        *)               level_num=$LOG_LEVEL_INFO ;;
    esac
    
    # Only output if level is at or above current log level
    if [ $level_num -ge $CURRENT_LOG_LEVEL ]; then
        case "$level" in
            "$LOG_DEBUG")   echo -e "\033[36m[${timestamp}] [${level}] [${operation}] ${message}\033[0m" ;;
            "$LOG_INFO")    echo -e "\033[32m[${timestamp}] [${level}] [${operation}] ${message}\033[0m" ;;
            "$LOG_WARN")    echo -e "\033[33m[${timestamp}] [${level}] [${operation}] ${message}\033[0m" ;;
            "$LOG_ERROR")   echo -e "\033[31m[${timestamp}] [${level}] [${operation}] ${message}\033[0m" ;;
            "$LOG_CRITICAL") echo -e "\033[41m[${timestamp}] [${level}] [${operation}] ${message}\033[0m" ;;
            *)              echo -e "[${timestamp}] [${level}] [${operation}] ${message}" ;;
        esac
    fi
    
    # Always log to file without color codes
    echo "[${timestamp}] [${level}] [${PID}] [${operation}] ${message}" >> "${LOG_FILE}"
}

# Create a recovery script to fix issues
create_recovery_script() {
    local issue="$1"
    local operation="$2"
    local fix_command="$3"
    
    log "$LOG_INFO" "$OP_RECOVERY" "Creating recovery script for issue: $issue"
    
    cat > "${RECOVERY_SCRIPT}" << EOF
#!/bin/bash
# Recovery script generated at $(date) for issue: ${issue}
# Operation: ${operation}

echo "Running recovery operations for ${issue}..."
${fix_command}
echo "Recovery complete. Please check system status."
EOF
    
    chmod +x "${RECOVERY_SCRIPT}"
    log "$LOG_INFO" "$OP_RECOVERY" "Recovery script created at ${RECOVERY_SCRIPT}"
}

# Error handler function with recovery capabilities
error_handler() {
    local line_no=$1
    local command="$2"
    local exit_code=$3
    local operation="${CURRENT_OPERATION:-UNKNOWN}"
    
    log "$LOG_ERROR" "$operation" "Error at line ${line_no}: Command '${command}' exited with status ${exit_code}"
    
    # Record error details for later analysis
    echo "[$(date)] ERROR in ${operation}: line ${line_no}, command '${command}', exit code ${exit_code}" >> "${LOG_DIR}/error-history.log"
    
    # Create recovery script based on error type
    case $exit_code in
        $RC_PERMISSION)
            create_recovery_script "Permission denied" "$operation" "chmod -R 755 ${PROJECT_DIR}; sudo chown -R $(whoami):$(whoami) ${PROJECT_DIR}"
            ;;
        $RC_NOT_FOUND)
            create_recovery_script "File not found" "$operation" "mkdir -p ${PROJECT_DIR}; touch ${SETUP_FLAG_FILE}"
            ;;
        $RC_TIMEOUT)
            create_recovery_script "Operation timeout" "$operation" "killall -9 $(echo $command | awk '{print $1}') 2>/dev/null; sleep 5"
            ;;
        *)
            # Generic recovery
            create_recovery_script "Generic error" "$operation" "echo 'Attempting generic recovery'; touch ${SETUP_FLAG_FILE}"
            ;;
    esac
    
    # For critical errors, exit immediately
    if [ $exit_code -ge $RC_CRITICAL ]; then
        log "$LOG_CRITICAL" "$operation" "Critical error occurred. Exiting script."
        exit $exit_code
    fi
    
    # Otherwise, continue with a warning
    return $RC_WARN
}

# Set up error handling
trap 'error_handler ${LINENO} "${BASH_COMMAND}" $?' ERR

# Function to execute commands with robust error handling and retry logic
execute() {
    local cmd="$1"
    local operation="$2"
    local retries=${3:-$MAX_RETRIES}
    local delay=${4:-$RETRY_DELAY}
    local timeout=${5:-$TIMEOUT}
    local attempt=1
    local status=0
    
    log "$LOG_INFO" "$operation" "Executing command: $cmd"
    
    # Mark the current operation for error handler
    CURRENT_OPERATION="$operation"
    
    # Try the command with retries
    while [ $attempt -le $retries ]; do
        if [ $attempt -gt 1 ]; then
            log "$LOG_WARN" "$operation" "Retry attempt $attempt/$retries after waiting $delay seconds"
            sleep $delay
        fi
        
        # Use timeout to prevent commands from hanging
        if command -v timeout >/dev/null 2>&1; then
            timeout $timeout bash -c "$cmd" 2>> "${LOG_FILE}"
            status=$?
        else
            # Fallback if timeout command is not available
            bash -c "$cmd" 2>> "${LOG_FILE}"
            status=$?
        fi
        
        if [ $status -eq 0 ]; then
            log "$LOG_INFO" "$operation" "Command completed successfully"
            return $RC_SUCCESS
        elif [ $status -eq $RC_TIMEOUT ]; then
            log "$LOG_WARN" "$operation" "Command timed out after $timeout seconds"
        else
            log "$LOG_WARN" "$operation" "Command failed with status $status"
        fi
        
        attempt=$((attempt + 1))
    done
    
    log "$LOG_ERROR" "$operation" "Command failed after $retries attempts"
    return $RC_ERROR
}

# Comprehensive variable dump with sanitization for sensitive info
debug_dump_variables() {
    if [ "$DEBUG" = true ]; then
        log "$LOG_DEBUG" "$OP_DEBUG" "------------ DEBUG VARIABLE DUMP ------------"
        log "$LOG_DEBUG" "$OP_DEBUG" "SCRIPT_NAME: $SCRIPT_NAME"
        log "$LOG_DEBUG" "$OP_DEBUG" "SCRIPT_VERSION: $SCRIPT_VERSION"
        log "$LOG_DEBUG" "$OP_DEBUG" "START_TIME: $START_TIME"
        log "$LOG_DEBUG" "$OP_DEBUG" "HOSTNAME: $HOSTNAME"
        log "$LOG_DEBUG" "$OP_DEBUG" "PID: $PID"
        log "$LOG_DEBUG" "$OP_DEBUG" "SCRIPT_DIR: $SCRIPT_DIR"
        log "$LOG_DEBUG" "$OP_DEBUG" "LOG_DIR: $LOG_DIR"
        log "$LOG_DEBUG" "$OP_DEBUG" "LOG_FILE: $LOG_FILE"
        log "$LOG_DEBUG" "$OP_DEBUG" "PROJECT_DIR: $PROJECT_DIR"
        log "$LOG_DEBUG" "$OP_DEBUG" "SETUP_FLAG_FILE: $SETUP_FLAG_FILE"
        log "$LOG_DEBUG" "$OP_DEBUG" "DOCKER_SOCKET: $DOCKER_SOCKET"
        log "$LOG_DEBUG" "$OP_DEBUG" "OPENAPI_GENERATOR_VERSION: $OPENAPI_GENERATOR_VERSION"
        log "$LOG_DEBUG" "$OP_DEBUG" "RESOURCES_DIR: $RESOURCES_DIR"
        log "$LOG_DEBUG" "$OP_DEBUG" "OPENAPI_DIR: $OPENAPI_DIR"
        log "$LOG_DEBUG" "$OP_DEBUG" "CONFIG_FILE: $CONFIG_FILE"
        log "$LOG_DEBUG" "$OP_DEBUG" "TEMPLATES_DIR: $TEMPLATES_DIR"
        log "$LOG_DEBUG" "$OP_DEBUG" "CLIENT_OUTPUT_DIR: $CLIENT_OUTPUT_DIR"
        log "$LOG_DEBUG" "$OP_DEBUG" "MAX_RETRIES: $MAX_RETRIES"
        log "$LOG_DEBUG" "$OP_DEBUG" "RETRY_DELAY: $RETRY_DELAY"
        log "$LOG_DEBUG" "$OP_DEBUG" "TIMEOUT: $TIMEOUT"
        log "$LOG_DEBUG" "$OP_DEBUG" "CHECK_INTERVAL: $CHECK_INTERVAL"
        log "$LOG_DEBUG" "$OP_DEBUG" "CURRENT_LOG_LEVEL: $CURRENT_LOG_LEVEL"
        log "$LOG_DEBUG" "$OP_DEBUG" "PATH: $PATH"
        log "$LOG_DEBUG" "$OP_DEBUG" "JAVA_HOME: $JAVA_HOME"
        log "$LOG_DEBUG" "$OP_DEBUG" "USER: $USER"
        log "$LOG_DEBUG" "$OP_DEBUG" "HOME: $HOME"
        
        # Sanitize and show any additional environment variables
        log "$LOG_DEBUG" "$OP_DEBUG" "--------- ENVIRONMENT VARIABLES ---------"
        env | sort | grep -v -E "PASSWORD|SECRET|TOKEN|KEY" | while read -r line; do
            log "$LOG_DEBUG" "$OP_DEBUG" "$line"
        done
        
        # System information
        log "$LOG_DEBUG" "$OP_DEBUG" "------------ SYSTEM INFORMATION ------------"
        log "$LOG_DEBUG" "$OP_DEBUG" "OS: $(uname -a)"
        log "$LOG_DEBUG" "$OP_DEBUG" "CPU: $(grep "model name" /proc/cpuinfo | head -1 | cut -d ':' -f 2 | sed 's/^[ \t]*//')"
        log "$LOG_DEBUG" "$OP_DEBUG" "Memory: $(free -h | grep "Mem" | awk '{print $2}' | sed 's/^[ \t]*//')"
        log "$LOG_DEBUG" "$OP_DEBUG" "Disk: $(df -h / | tail -1 | awk '{print $2}')"
        
        # Project directory structure
        log "$LOG_DEBUG" "$OP_DEBUG" "------------ PROJECT DIRECTORY ------------"
        if [ -d "$PROJECT_DIR" ]; then
            log "$LOG_DEBUG" "$OP_DEBUG" "$(ls -la "$PROJECT_DIR" | head -20)"
            [ $(ls -la "$PROJECT_DIR" | wc -l) -gt 20 ] && log "$LOG_DEBUG" "$OP_DEBUG" "(truncated output)"
        else
            log "$LOG_DEBUG" "$OP_DEBUG" "Project directory does not exist: $PROJECT_DIR"
        fi
        
        log "$LOG_DEBUG" "$OP_DEBUG" "------------ END DEBUG DUMP ------------"
    fi
}

# Verify Docker socket permissions
verify_docker_socket() {
    log "$LOG_INFO" "$OP_DOCKER_SOCKET" "Verifying Docker socket access"
    
    if [ ! -e "${DOCKER_SOCKET}" ]; then
        log "$LOG_ERROR" "$OP_DOCKER_SOCKET" "Docker socket not found at ${DOCKER_SOCKET}"
        return $RC_ERROR
    fi
    
    if ! execute "docker ps &>/dev/null" "$OP_DOCKER_SOCKET"; then
        log "$LOG_WARN" "$OP_DOCKER_SOCKET" "Docker access issue detected. Attempting to fix permissions."
        
        # Try to fix permissions
        if execute "sudo chmod 666 ${DOCKER_SOCKET}" "$OP_DOCKER_SOCKET"; then
            log "$LOG_INFO" "$OP_DOCKER_SOCKET" "Fixed Docker socket permissions"
        else
            log "$LOG_ERROR" "$OP_DOCKER_SOCKET" "Failed to fix Docker socket permissions"
            return $RC_ERROR
        fi
        
        # Verify again
        if ! execute "docker ps &>/dev/null" "$OP_DOCKER_SOCKET"; then
            log "$LOG_ERROR" "$OP_DOCKER_SOCKET" "Still cannot access Docker. Check service status."
            return $RC_ERROR
        fi
    fi
    
    log "$LOG_INFO" "$OP_DOCKER_SOCKET" "Docker socket verified and working"
    return $RC_SUCCESS
}

# Check if we are running in WSL environment
check_wsl_environment() {
    log "$LOG_INFO" "$OP_WSL_CHECK" "Checking for WSL environment"
    
    if grep -q -E "Microsoft|WSL" /proc/version; then
        log "$LOG_INFO" "$OP_WSL_CHECK" "WSL environment detected"
        
        # Check Docker Desktop setup
        if ! docker info &>/dev/null; then
            log "$LOG_WARN" "$OP_WSL_CHECK" "Docker is not accessible in WSL. Make sure Docker Desktop is running with WSL integration enabled."
            return $RC_WARN
        fi
        
        # Check Docker socket access
        if [ ! -e "${DOCKER_SOCKET}" ]; then
            log "$LOG_WARN" "$OP_WSL_CHECK" "Docker socket not found in WSL at ${DOCKER_SOCKET}"
            return $RC_WARN
        fi
        
        log "$LOG_INFO" "$OP_WSL_CHECK" "WSL configuration for Docker appears correct"
        return $RC_SUCCESS
    else
        log "$LOG_INFO" "$OP_WSL_CHECK" "Not running in WSL environment"
        return $RC_SUCCESS
    fi
}

# Check project directory structure
check_project_structure() {
    log "$LOG_INFO" "$OP_DIRECTORY" "Validating project directory structure"
    
    if [ ! -d "$PROJECT_DIR" ]; then
        log "$LOG_ERROR" "$OP_DIRECTORY" "Project directory does not exist: $PROJECT_DIR"
        return $RC_ERROR
    fi
    
    # Check essential directories
    for dir in "${OPENAPI_DIR}" "${RESOURCES_DIR}" "${TEMPLATES_DIR}"; do
        if [ ! -d "$dir" ]; then
            log "$LOG_WARN" "$OP_DIRECTORY" "Directory does not exist: $dir"
            execute "mkdir -p $dir" "$OP_DIRECTORY"
        fi
    done
    
    # Check for essential files
    if [ ! -f "${PROJECT_DIR}/gradlew" ]; then
        log "$LOG_WARN" "$OP_DIRECTORY" "Gradle wrapper not found"
    else
        execute "chmod +x ${PROJECT_DIR}/gradlew" "$OP_PERMISSIONS"
    fi
    
    log "$LOG_INFO" "$OP_DIRECTORY" "Project directory structure validated"
    return $RC_SUCCESS
}

# Create a health status file for container health checks
update_health_status() {
    log "$LOG_DEBUG" "$OP_HEALTH" "Updating container health status"
    
    echo "Container ID: ${CONTAINER_ID}" > "${HEALTH_FILE}"
    echo "Last update: $(date)" >> "${HEALTH_FILE}"
    echo "Status: HEALTHY" >> "${HEALTH_FILE}"
    echo "Uptime: $(uptime)" >> "${HEALTH_FILE}"
    
    chmod 644 "${HEALTH_FILE}"
    log "$LOG_DEBUG" "$OP_HEALTH" "Health status updated"
}

#===============================================================================
# MAIN EXECUTION FLOW
#===============================================================================

main() {
    log "$LOG_INFO" "$OP_INIT" "Starting DocumentReader Web Java Client development container"
    log "$LOG_INFO" "$OP_INIT" "Version: $SCRIPT_VERSION"
    
    # Debug information if enabled
    debug_dump_variables
    
    # Verify environment
    check_wsl_environment
    verify_docker_socket
    check_project_structure
    
    # Create health status file
    update_health_status
    
    # Make sure gradlew has execute permissions
    if [ -f "${PROJECT_DIR}/gradlew" ]; then
        execute "chmod +x ${PROJECT_DIR}/gradlew" "$OP_PERMISSIONS"
    fi
    
    log "$LOG_INFO" "$OP_CONTAINER_READY" "Development container ready for use"
    
    # Schedule periodic health updates
    (
        while true; do
            sleep ${CHECK_INTERVAL}
            update_health_status
        done
    ) &
    
    # Execute the command provided to the script
    log "$LOG_INFO" "$OP_EXEC" "Executing command: $*"
    exec "$@"
}

# Run the main function
main "$@"