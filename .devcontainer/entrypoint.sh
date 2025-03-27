#!/bin/bash
set -e

# Check if we need to run the setup
if [ -f "/tmp/needs_setup" ]; then
    echo "🚀 Initial container setup in progress..."
    
    cd /workspaces/DocumentReader-web-java-client
    
    # Make executable
    chmod +x gradlew update-models.sh
    
    # Create test resources directory
    mkdir -p example/src/main/resources
    
    # Fix Docker socket permissions
    if [ -e /var/run/docker.sock ]; then
        chmod 666 /var/run/docker.sock
    fi
    
    # Generate models from existing cloned OpenAPI definitions
    echo "📦 Generating models from OpenAPI definitions in ../DocumentReader-web-openapi..."
    ./update-models.sh || echo "⚠️ Model generation failed but continuing"
    
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