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

# Important: Remove the strict error handling to prevent container from crashing
# set -eo pipefail

#===============================================================================
# CONSTANTS AND TYPE DECLARATIONS
#===============================================================================

# Source environment variables if not already set
if [ -f "/workspaces/DocumentReader-web-java-client/.devcontainer/.env" ]; then
    source "/workspaces/DocumentReader-web-java-client/.devcontainer/.env"
fi

# Set defaults for critical environment variables if not provided
: "${PROJECT_DIR:=/workspaces/DocumentReader-web-java-client}"
: "${SETUP_FLAG_FILE:=/tmp/needs_setup}"
: "${DOCKER_SOCKET:=/var/run/docker.sock}"
: "${OPENAPI_GENERATOR_VERSION:=v5.0.0-beta2}"
: "${RESOURCES_DIR:=${PROJECT_DIR}/example/src/main/resources}"
: "${OPENAPI_DIR:=${PROJECT_DIR}/openapi}"
: "${CONFIG_FILE:=${PROJECT_DIR}/client/java-generator-config.json}"
: "${TEMPLATES_DIR:=${PROJECT_DIR}/client/generator-templates}"
: "${CLIENT_OUTPUT_DIR:=${PROJECT_DIR}/client}"

# Log levels
readonly LOG_INFO="INFO"
readonly LOG_WARN="WARN"
readonly LOG_ERROR="ERROR"

# Operation types
readonly OP_PERMISSIONS="PERMISSIONS"
readonly OP_DIRECTORY="DIRECTORY"
readonly OP_DOCKER_SOCKET="DOCKER_SOCKET"
readonly OP_OPENAPI_GEN_FIRST="OPENAPI_GEN_FIRST"
readonly OP_OPENAPI_GEN_SECOND="OPENAPI_GEN_SECOND"
readonly OP_CODE_FORMAT="CODE_FORMAT"
readonly OP_BUILD="BUILD"
readonly OP_SETUP_BEGIN="SETUP_BEGIN"
readonly OP_SETUP_COMPLETE="SETUP_COMPLETE"
readonly OP_CONTAINER_READY="CONTAINER_READY"
readonly OP_EXEC="EXEC"
readonly OP_WSL_CHECK="WSL_CHECK"

#===============================================================================
# UTILITY FUNCTIONS
#===============================================================================

# Improved logging function with timestamp and color
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    case "$level" in
        "$LOG_INFO")
            echo -e "\033[32m[${timestamp}] [INFO] ${message}\033[0m"
            ;;
        "$LOG_WARN")
            echo -e "\033[33m[${timestamp}] [WARN] ${message}\033[0m"
            ;;
        "$LOG_ERROR")
            echo -e "\033[31m[${timestamp}] [ERROR] ${message}\033[0m"
            ;;
        *)
            echo -e "[${timestamp}] [${level}] ${message}"
            ;;
    esac
}

# Check if file exists
check_file_exists() {
    local file="$1"
    if [ -f "$file" ]; then
        return 0
    else
        return 1
    fi
}

# Check if directory exists
check_dir_exists() {
    local dir="$1"
    if [ -d "$dir" ]; then
        return 0
    else
        return 1
    fi
}

# Execute command with logging
execute() {
    local cmd="$1"
    local operation="$2"
    
    log "$LOG_INFO" "[$operation] Executing: $cmd"
    eval "$cmd"
    local status=$?
    
    if [ $status -ne 0 ]; then
        log "$LOG_WARN" "[$operation] Command exited with status $status"
    else
        log "$LOG_INFO" "[$operation] Command completed successfully"
    fi
    
    return $status
}

# Check WSL configuration
check_wsl_config() {
    if grep -q Microsoft /proc/version || grep -q WSL /proc/version; then
        log "$LOG_INFO" "[$OP_WSL_CHECK] WSL detected, verifying configuration"
        
        # Check Docker Desktop integration
        if ! docker info &>/dev/null; then
            log "$LOG_WARN" "[$OP_WSL_CHECK] Docker is not accessible. Please check Docker Desktop is running and WSL integration is enabled."
            log "$LOG_INFO" "[$OP_WSL_CHECK] You can enable WSL integration in Docker Desktop settings > Resources > WSL Integration"
            return 1
        fi
        
        # Check Docker socket access
        if ! check_file_exists "${DOCKER_SOCKET}"; then
            log "$LOG_WARN" "[$OP_WSL_CHECK] Docker socket not found at ${DOCKER_SOCKET}"
            return 1
        fi
        
        log "$LOG_INFO" "[$OP_WSL_CHECK] WSL configuration appears correct"
    else
        log "$LOG_INFO" "[$OP_WSL_CHECK] Not running in WSL environment"
    fi
    return 0
}

# Verify Docker socket permissions and accessibility
verify_docker_socket() {
    log "$LOG_INFO" "[$OP_DOCKER_SOCKET] Verifying Docker socket access"
    
    if ! check_file_exists "${DOCKER_SOCKET}"; then
        log "$LOG_ERROR" "[$OP_DOCKER_SOCKET] Docker socket not found at ${DOCKER_SOCKET}"
        log "$LOG_INFO" "[$OP_DOCKER_SOCKET] Please ensure Docker is running and the socket is correctly mounted"
        return 1
    fi
    
    # Set socket permissions if needed
    execute "chmod 666 ${DOCKER_SOCKET}" "${OP_DOCKER_SOCKET}"
    
    # Verify Docker works
    if ! docker ps &>/dev/null; then
        log "$LOG_ERROR" "[$OP_DOCKER_SOCKET] Docker command failed. Check permissions and Docker service status."
        return 1
    fi
    
    log "$LOG_INFO" "[$OP_DOCKER_SOCKET] Docker socket verified and accessible"
    return 0
}

#===============================================================================
# MAIN EXECUTION FLOW
#===============================================================================

# Setup error handling to continue on errors
trap 'log "${LOG_ERROR}" "Command \"${BASH_COMMAND}\" failed with exit code $?, continuing"' ERR

# Change to project directory
cd "${PROJECT_DIR}" || {
    log "${LOG_ERROR}" "Failed to change to project directory: ${PROJECT_DIR}"
    exit 1
}

# Check WSL configuration if relevant
check_wsl_config

# Verify Docker socket permissions
verify_docker_socket

# Check and set file permissions for key scripts
if check_file_exists "${PROJECT_DIR}/gradlew"; then
    execute "chmod +x gradlew" "${OP_PERMISSIONS}"
fi

# Mark container as ready
log "${LOG_INFO}" "[$OP_CONTAINER_READY] Development container ready for use"

# Execute the command provided to the script
exec "$@"