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

set -eo pipefail

#===============================================================================
# CONSTANTS AND TYPE DECLARATIONS
#===============================================================================
readonly WORKSPACE_DIR="/workspaces/DocumentReader-web-java-client"
readonly SETUP_FLAG_FILE="/tmp/needs_setup"
readonly DOCKER_SOCKET="/var/run/docker.sock"
readonly OPENAPI_GENERATOR_VERSION="v5.0.0-beta2"

# Resource paths
readonly RESOURCES_DIR="${WORKSPACE_DIR}/example/src/main/resources"
readonly OPENAPI_DIR="${WORKSPACE_DIR}/openapi"
readonly CONFIG_FILE="${WORKSPACE_DIR}/client/java-generator-config.json"
readonly TEMPLATES_DIR="${WORKSPACE_DIR}/client/generator-templates"
readonly CLIENT_OUTPUT_DIR="${WORKSPACE_DIR}/client"

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

# Type mappings for OpenAPI generation
readonly ENUM_MAPPINGS="MeasureSystem=Integer,TextFieldType=Integer,GraphicFieldType=Integer,\
Scenario=String,DocumentFormat=Integer,Light=Integer,Result=Integer,\
VerificationResult=Integer,RfidLocation=Integer,DocumentTypeRecognitionResult=Integer,\
ProcessingStatus=Integer,Source=String,CheckResult=Integer,LCID=Integer,\
DocumentType=Integer,CheckDiagnose=Integer,Critical=Integer,AuthenticityResultType=Integer,\
SecurityFeatureType=Integer,Visibility=Integer,ImageQualityCheckType=Integer,\
LogLevel=String,MRZFormat=String,TextPostProcessing=Integer"

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
        return 1
    }
    
    # Success block
    log "${LOG_INFO}" "${operation}: Operation completed successfully"
    return 0
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
    
    local base_command="docker run --user $(id -u):$(id -g) --rm \
-v ${WORKSPACE_DIR}:/client \
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
}

# Function: setup_environment
# Purpose: Perform initial environment setup
# Parameters: None
# Returns: None
function setup_environment() {
    log "${LOG_INFO}" "${OP_SETUP_BEGIN}: Container initialization started"
    
    cd "${WORKSPACE_DIR}"
    
    # Setup phase
    execute "chmod +x gradlew" "${OP_PERMISSIONS}"
    execute "mkdir -p ${RESOURCES_DIR}" "${OP_DIRECTORY}"
    
    if [ -e "${DOCKER_SOCKET}" ]; then
        execute "chmod 666 ${DOCKER_SOCKET}" "${OP_DOCKER_SOCKET}"
    fi
    
    # OpenAPI generation phase
    run_openapi_generation "${OP_OPENAPI_GEN_FIRST}"
    run_openapi_generation "${OP_OPENAPI_GEN_SECOND}" "--import-mappings \"${ENUM_MAPPINGS}\""
    
    # Build phase
    if command -v ./gradlew &>/dev/null; then
        execute "./gradlew -p ./ goJF" "${OP_CODE_FORMAT}"
    fi
    
    execute "./gradlew --no-daemon build -x test" "${OP_BUILD}"
    
    # Cleanup phase
    log "${LOG_INFO}" "${OP_SETUP_COMPLETE}: Container initialization finished"
    rm "${SETUP_FLAG_FILE}"
}

#===============================================================================
# MAIN EXECUTION BLOCK
#===============================================================================

# Setup global error handler (like try/catch for the entire script)
trap 'log "${LOG_ERROR}" "Command \"${BASH_COMMAND}\" failed with exit code $?"' ERR

# Determine if setup is needed (main branching logic)
if [ -f "${SETUP_FLAG_FILE}" ]; then
    setup_environment
else
    log "${LOG_INFO}" "${OP_CONTAINER_READY}: Setup already completed"
fi

# Final execution (like finally block)
log "${LOG_INFO}" "${OP_EXEC}: Executing command '$@'"
exec "$@"