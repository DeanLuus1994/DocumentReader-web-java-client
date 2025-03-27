#!/bin/bash
set -e

# Function to check if command exists and install if not
check_and_install() {
    local cmd=$1
    local pkg=$2
    if ! command -v $cmd &> /dev/null; then
        echo "🔧 Installing $pkg..."
        apt-get update && apt-get install -y $pkg
    fi
}

# Check if we need to run the setup
if [ -f "/tmp/needs_setup" ]; then
    echo "🚀 Initial container setup in progress..."
    
    # Make sure the workspace directory exists
    mkdir -p /workspaces
    
    # Check for essential tools
    check_and_install git git
    check_and_install docker docker-ce
    
    # Only run if we're in the workspace directory
    if [ -d "/workspaces/DocumentReader-web-java-client" ]; then
        cd /workspaces/DocumentReader-web-java-client
        
        # Make sure scripts are executable
        if [ -f "gradlew" ]; then
            chmod +x gradlew
        else
            echo "⚠️ gradlew not found - will be created later"
        fi
        
        if [ -f "update-models.sh" ]; then
            chmod +x update-models.sh
        else
            echo "⚠️ update-models.sh not found - will be created later"
        fi
        
        if [ -f "setup-and-test-regula.sh" ]; then
            chmod +x setup-and-test-regula.sh
        fi
        
        # Clone the DocumentReader-web-openapi repository if not present
        if [ ! -d "../DocumentReader-web-openapi" ]; then
            echo "📋 Cloning OpenAPI definitions repository..."
            cd ..
            git clone https://github.com/regulaforensics/DocumentReader-web-openapi.git
            cd /workspaces/DocumentReader-web-java-client
        fi

        # Ensure git is properly initialized
        if [ ! -d ".git" ]; then
            echo "📋 Initializing git repository..."
            git init
        fi
        
        # Ensure Gradle wrapper is present
        if [ ! -f "gradlew" ] || [ ! -d "gradle" ]; then
            echo "📦 Setting up Gradle wrapper..."
            # If gradle directory doesn't exist, create minimal structure
            mkdir -p gradle/wrapper
            
            # Create minimal gradle-wrapper.properties
            cat > gradle/wrapper/gradle-wrapper.properties << 'EOF'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-7.6-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF

            # Download gradle wrapper jar
            mkdir -p gradle/wrapper
            curl -o gradle/wrapper/gradle-wrapper.jar https://repo.maven.apache.org/maven2/org/gradle/gradle-wrapper/7.6/gradle-wrapper-7.6.jar
            
            # Create gradlew script
            cat > gradlew << 'EOF'
#!/bin/sh
exec java -jar "$0.jar" "$@"
EOF
            chmod +x gradlew
            
            echo "✅ Gradle wrapper setup complete"
        fi
        
        # Ensure test resources directory exists
        mkdir -p /workspaces/DocumentReader-web-java-client/example/src/main/resources
        
        # Check if Docker is running
        if ! docker info > /dev/null 2>&1; then
            echo "⚠️ Docker is not running. Attempting to start docker service..."
            service docker start || true
            sleep 5
        fi
        
        # Generate models from OpenAPI definitions
        if [ -f "update-models.sh" ]; then
            echo "📦 Generating models from OpenAPI definitions..."
            ./update-models.sh || echo "⚠️ Model generation failed but continuing"
        else
            echo "⚠️ update-models.sh not found - skipping model generation"
        fi
        
        # Build project with Gradle
        if [ -f "gradlew" ]; then
            echo "🔨 Building project with Gradle..."
            ./gradlew --no-daemon build -x test || echo "⚠️ Build failed but continuing"
        else
            echo "⚠️ gradlew not found - skipping build"
        fi
        
        echo "⚠️ Note: For full API testing, add your regula.license file to example/src/main/resources/"
        
        echo "✅ Initial setup complete!"
        rm /tmp/needs_setup
    else
        echo "⚠️ Project directory not found at /workspaces/DocumentReader-web-java-client"
        echo "   Creating minimal project structure..."
        
        # Create project directory if it doesn't exist
        mkdir -p /workspaces/DocumentReader-web-java-client
        cd /workspaces/DocumentReader-web-java-client
        
        # Initialize git
        git init
        
        # Create minimal project structure
        mkdir -p example/src/main/{java,resources}
        mkdir -p client/src/main/java
        
        # Create minimal build.gradle.kts
        cat > build.gradle.kts << 'EOF'
import org.gradle.plugins.ide.idea.model.IdeaLanguageLevel

plugins {
    idea
}

allprojects {
    group = "com.regula.documentreader"

    repositories {
        google()
        mavenCentral()
    }
}

idea {
    project {
        languageLevel = IdeaLanguageLevel(JavaVersion.VERSION_11)
    }
}
EOF

        # Create settings.gradle.kts
        cat > settings.gradle.kts << 'EOF'
include("client", "example")
EOF

        # Create minimal update-models.sh
        cat > update-models.sh << 'EOF'
#!/bin/sh

DOCS_DEFINITION_FOLDER="${PWD}/../DocumentReader-web-openapi" \
\
&& ENUM_MAPPINGS="MeasureSystem=Integer,TextFieldType=Integer,GraphicFieldType=Integer,Scenario=String,DocumentFormat=Integer,\
Light=Integer,Result=Integer,VerificationResult=Integer,RfidLocation=Integer,\
DocumentTypeRecognitionResult=Integer,ProcessingStatus=Integer,Source=String,CheckResult=Integer,\
LCID=Integer,DocumentType=Integer,CheckDiagnose=Integer,Critical=Integer,AuthenticityResultType=Integer,\
SecurityFeatureType=Integer,Visibility=Integer,ImageQualityCheckType=Integer,\
LogLevel=String,MRZFormat=String,TextPostProcessing=Integer" \
\
&& docker run --user "$(id -u):$(id -g)" --rm -v "${PWD}:/client" -v "$DOCS_DEFINITION_FOLDER:/definitions" \
openapitools/openapi-generator-cli:v5.0.0-beta2 generate \
-i /definitions/index.yml -g java -o /client/client \
-c /client/java-generator-config.json -t /client/client/generator-templates/ \
\
&& docker run --user "$(id -u):$(id -g)" --rm -v "${PWD}:/client" -v "${DOCS_DEFINITION_FOLDER}:/definitions" \
openapitools/openapi-generator-cli:v5.0.0-beta2 generate \
-i /definitions/index.yml -g java -o /client/client \
-c /client/java-generator-config.json -t /client/client/generator-templates/ \
--import-mappings $ENUM_MAPPINGS \
\
|| exit 1

if command -v ./gradlew &> /dev/null; then
    ./gradlew -p ./ goJF
fi
exit 0
EOF
        chmod +x update-models.sh
        
        # Create java-generator-config.json
        cat > java-generator-config.json << 'EOF'
{
  "artifactId": "webclient",
  "artifactVersion": "5.1.0",
  "groupId": "com.regula.documentreader",
  "library": "okhttp-gson",
  "useRuntimeException": true,
  "hideGenerationTimestamp": true,
  "invokerPackage": "com.regula.documentreader.webclient",
  "modelPackage": "com.regula.documentreader.webclient.model",
  "apiPackage": "com.regula.documentreader.webclient.api",
  "sourceFolder": "src/main/generated",
  "typeMappings" : {
    "TextField" : "com.regula.documentreader.webclient.model.ext.TextField",
    "ImagesField" : "com.regula.documentreader.webclient.model.ext.ImagesField",
    "Text": "com.regula.documentreader.webclient.model.ext.Text",
    "Images" : "com.regula.documentreader.webclient.model.ext.Images",
    "AuthenticityCheckList" : "com.regula.documentreader.webclient.model.ext.authenticity.Authenticity"
  }
}
EOF

        # Create minimal README.md
        cat > README.md << 'EOF'
# Regula Document Reader java client compatible with jvm and android

Workspace initialized by dev container. Follow setup instructions to complete project configuration.
EOF

        echo "✅ Minimal project structure created"
        rm /tmp/needs_setup
    fi
else
    echo "🔄 Container restarted - setup already completed"
fi

# Make sure Docker socket has correct permissions
if [ -e /var/run/docker.sock ]; then
    if [ "$(stat -c '%G' /var/run/docker.sock)" != "docker" ]; then
        echo "🔧 Fixing Docker socket permissions..."
        chown root:docker /var/run/docker.sock
    fi
fi

# Execute the command passed to docker run
exec "$@"