#!/bin/bash
set -e

# Check if we need to run the setup
if [ -f "/tmp/needs_setup" ]; then
    echo "🚀 Initial container setup in progress..."
    
    # Only run if we're in the workspace directory
    if [ -f "/workspaces/DocumentReader-web-java-client/gradlew" ]; then
        cd /workspaces/DocumentReader-web-java-client
        
        # Make sure scripts are executable (in case of git clone or other operations that might change permissions)
        chmod +x gradlew
        chmod +x update-models.sh
        if [ -f "setup-and-test-regula.sh" ]; then
            chmod +x setup-and-test-regula.sh
        fi
        
        echo "📦 Generating models from OpenAPI definitions..."
        ./update-models.sh || echo "⚠️ Model generation failed but continuing"
        
        echo "🔨 Building project with Gradle..."
        ./gradlew --no-daemon build -x test || echo "⚠️ Build failed but continuing"
        
        echo "✅ Initial setup complete!"
        rm /tmp/needs_setup
    else
        echo "⚠️ Project files not found - skipping setup"
        echo "   If you've just cloned the repository, try restarting the container"
    fi
fi

# Execute the command passed to docker run
exec "$@"