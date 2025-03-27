#!/bin/bash
# filepath: /workspaces/DocumentReader-web-java-client/.devcontainer/entrypoint.sh
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

# Use environment variable or default value for enum mappings
: "${ENUM_MAPPINGS:=MeasureSystem=Integer,TextFieldType=Integer,GraphicFieldType=Integer,Scenario=String,DocumentFormat=Integer,Light=Integer,Result=Integer,VerificationResult=Integer,RfidLocation=Integer,DocumentTypeRecognitionResult=Integer,ProcessingStatus=Integer,Source=String,CheckResult=Integer,LCID=Integer,DocumentType=Integer,CheckDiagnose=Integer,Critical=Integer,AuthenticityResultType=Integer,SecurityFeatureType=Integer,Visibility=Integer,ImageQualityCheckType=Integer,LogLevel=String,MRZFormat=String,TextPostProcessing=Integer}"

#===============================================================================
# FUNCTION DECLARATIONS
#===============================================================================

# Function: log
# Purpose: Output standardized log messages with timestamp
# Parameters:
#   $1: Log level (INFO, WARN, ERROR)
#   $2: Message text
# Returns: None
function log() {
    local level="$1"
    local message="$2"
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [${level}] ${message}"
}

# Function: execute
# Purpose: Execute a command with standardized logging and error handling
# Parameters:
#   $1: Command to execute
#   $2: Operation identifier for logs
# Returns: 0 on success, 1 on failure
function execute() {
    local command="$1"
    local operation="$2"
    
    log "${LOG_INFO}" "${operation}: Starting operation"
    
    # Try block
    eval "${command}" || {
        # Catch block
        local exit_code=$?
        log "${LOG_WARN}" "${operation}: Operation failed with code ${exit_code}, continuing"
        # Return success anyway to prevent container restart
        return 0
    }
    
    # Success block
    log "${LOG_INFO}" "${operation}: Operation completed successfully"
    return 0
}

# Function: check_directory_exists
# Purpose: Check if a directory exists
# Parameters:
#   $1: Directory path
# Returns: 0 if exists, 1 if not
function check_directory_exists() {
    local dir_path="$1"
    if [ -d "${dir_path}" ]; then
        return 0
    else
        return 1
    fi
}

# Function: check_file_exists
# Purpose: Check if a file exists
# Parameters:
#   $1: File path
# Returns: 0 if exists, 1 if not
function check_file_exists() {
    local file_path="$1"
    if [ -f "${file_path}" ]; then
        return 0
    else
        return 1
    fi
}

# Function: run_openapi_generation
# Purpose: Run the OpenAPI generator with specific parameters
# Parameters:
#   $1: Operation identifier
#   $2: Additional parameters (optional)
# Returns: Result of execute function
function run_openapi_generation() {
    local operation="$1"
    local additional_params="$2"
    
    # Verify OpenAPI directory exists
    if ! check_directory_exists "${OPENAPI_DIR}"; then
        log "${LOG_WARN}" "${operation}: OpenAPI directory not found, skipping generation"
        return 0
    fi
    
    # Verify index.yml exists
    if ! check_file_exists "${OPENAPI_DIR}/index.yml"; then
        log "${LOG_WARN}" "${operation}: OpenAPI index.yml not found, skipping generation"
        return 0
    fi
    
    # Verify client directory and config exist
    if ! check_directory_exists "${PROJECT_DIR}/client"; then
        log "${LOG_WARN}" "${operation}: Client directory not found, creating it"
        mkdir -p "${PROJECT_DIR}/client"
    fi
    
    # Check if Docker socket is available
    if ! check_file_exists "${DOCKER_SOCKET}"; then
        log "${LOG_WARN}" "${operation}: Docker socket not available, skipping OpenAPI generation"
        return 0
    fi
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log "${LOG_WARN}" "${operation}: Docker daemon not running, skipping OpenAPI generation"
        return 0
    fi
    
    local base_command="docker run --user $(id -u):$(id -g) --rm \
-v ${PROJECT_DIR}:/client \
-v ${OPENAPI_DIR}:/definitions \
openapitools/openapi-generator-cli:${OPENAPI_GENERATOR_VERSION} generate \
-i /definitions/index.yml \
-g java \
-o /client/client \
-c /client/java-generator-config.json \
-t /client/client/generator-templates/"

    if [ -n "${additional_params}" ]; then
        base_command="${base_command} ${additional_params}"
    fi
    
    execute "${base_command}" "${operation}"
    return 0
}

# Function: setup_environment
# Purpose: Perform initial environment setup
# Parameters: None
# Returns: None
function setup_environment() {
    log "${LOG_INFO}" "${OP_SETUP_BEGIN}: Container initialization started"
    
    # Change to workspace directory safely
    cd "${PROJECT_DIR}" || {
        log "${LOG_ERROR}" "Failed to change to workspace directory"
        # Continue anyway
    }
    
    # Setup phase
    if check_file_exists "${PROJECT_DIR}/gradlew"; then
        execute "chmod +x gradlew" "${OP_PERMISSIONS}"
    else
        log "${LOG_WARN}" "${OP_PERMISSIONS}: gradlew not found, skipping permissions"
    fi
    
    execute "mkdir -p ${RESOURCES_DIR}" "${OP_DIRECTORY}"
    
    if check_file_exists "${DOCKER_SOCKET}"; then
        execute "chmod 666 ${DOCKER_SOCKET}" "${OP_DOCKER_SOCKET}"
    else
        log "${LOG_WARN}" "${OP_DOCKER_SOCKET}: Docker socket not found, skipping permissions"
    fi
    
    # OpenAPI generation phase - only if necessary conditions are met
    run_openapi_generation "${OP_OPENAPI_GEN_FIRST}"
    run_openapi_generation "${OP_OPENAPI_GEN_SECOND}" "--import-mappings \"${ENUM_MAPPINGS}\""
    
    # Build phase
    if check_file_exists "${PROJECT_DIR}/gradlew"; then
        if command -v ./gradlew &>/dev/null; then
            execute "./gradlew -p ./ goJF" "${OP_CODE_FORMAT}"
            execute "./gradlew --no-daemon build -x test" "${OP_BUILD}"
        else
            log "${LOG_WARN}" "Gradle wrapper found but not executable, skipping build"
        fi
    else
        log "${LOG_WARN}" "Gradle wrapper not found, skipping build"
    fi
    
    # Cleanup phase
    log "${LOG_INFO}" "${OP_SETUP_COMPLETE}: Container initialization finished"
    if check_file_exists "${SETUP_FLAG_FILE}"; then
        execute "rm ${SETUP_FLAG_FILE}" "CLEANUP"
    fi
}

#===============================================================================
# MAIN EXECUTION BLOCK
#===============================================================================

# Setup safer error handler that logs but doesn't terminate the script
trap 'log "${LOG_ERROR}" "Command \"${BASH_COMMAND}\" failed with exit code $?, continuing"' ERR

# Determine if setup is needed (main branching logic)
if check_file_exists "${SETUP_FLAG_FILE}"; then
    # Run setup but catch any errors to prevent container from failing
    setup_environment || {
        log "${LOG_ERROR}" "Setup failed, but container will continue running"
    }
else
    log "${LOG_INFO}" "${OP_CONTAINER_READY}: Setup already completed"
fi

# Final execution (like finally block)
log "${LOG_INFO}" "${OP_EXEC}: Executing command '$@'"
exec "$@"