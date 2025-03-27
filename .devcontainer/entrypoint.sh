#!/bin/bash
set -e

# Check if setup is needed
if [ -f "/tmp/needs_setup" ]; then
    echo "🚀 Initial container setup in progress..."
    
    cd /workspaces/DocumentReader-web-java-client
    
    # Make scripts executable and create resources dir
    chmod +x gradlew
    mkdir -p example/src/main/resources
    
    # Fix Docker socket permissions
    [ -e /var/run/docker.sock ] && chmod 666 /var/run/docker.sock
    
    # Generate models
    echo "📦 Generating models from OpenAPI definitions..."
    
    # Define OpenAPI directory and enum mappings
    DOCS_DEFINITION_FOLDER="${PWD}/openapi"
    ENUM_MAPPINGS="MeasureSystem=Integer,TextFieldType=Integer,GraphicFieldType=Integer,Scenario=String,DocumentFormat=Integer,\
Light=Integer,Result=Integer,VerificationResult=Integer,RfidLocation=Integer,\
DocumentTypeRecognitionResult=Integer,ProcessingStatus=Integer,Source=String,CheckResult=Integer,\
LCID=Integer,DocumentType=Integer,CheckDiagnose=Integer,Critical=Integer,AuthenticityResultType=Integer,\
SecurityFeatureType=Integer,Visibility=Integer,ImageQualityCheckType=Integer,\
LogLevel=String,MRZFormat=String,TextPostProcessing=Integer"
    
    # First pass of OpenAPI generator
    docker run --user "$(id -u):$(id -g)" --rm -v "${PWD}:/client" -v "$DOCS_DEFINITION_FOLDER:/definitions" \
    openapitools/openapi-generator-cli:v5.0.0-beta2 generate \
    -i /definitions/index.yml -g java -o /client/client \
    -c /client/java-generator-config.json -t /client/client/generator-templates/ || {
        echo "⚠️ First-pass model generation failed but continuing"
    }
    
    # Second pass with enum mappings
    docker run --user "$(id -u):$(id -g)" --rm -v "${PWD}:/client" -v "${DOCS_DEFINITION_FOLDER}:/definitions" \
    openapitools/openapi-generator-cli:v5.0.0-beta2 generate \
    -i /definitions/index.yml -g java -o /client/client \
    -c /client/java-generator-config.json -t /client/client/generator-templates/ \
    --import-mappings "$ENUM_MAPPINGS" || {
        echo "⚠️ Second-pass model generation failed but continuing"
    }
    
    # Code formatting if available
    if command -v ./gradlew &> /dev/null; then
        ./gradlew -p ./ goJF || echo "⚠️ Code formatting failed but continuing"
    fi
    
    # Build project
    echo "🔨 Building project with Gradle..."
    ./gradlew --no-daemon build -x test || echo "⚠️ Build failed but continuing"
    
    echo "✅ Setup complete! Add regula.license to example/src/main/resources/ for API testing."
    rm /tmp/needs_setup
else
    echo "🔄 Container ready - setup already completed"
fi

# Execute the command passed to docker run
exec "$@"