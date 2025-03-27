# syntax=docker/dockerfile:1.4

FROM mcr.microsoft.com/devcontainers/java:17

# Set working directory to match the workspace folder in devcontainer.json
WORKDIR /workspaces/DocumentReader-web-java-client

# Configure Gradle user home and ensure its directory exists
ENV GRADLE_USER_HOME=/home/vscode/.gradle
RUN mkdir -p ${GRADLE_USER_HOME}

# Install Docker and Docker Compose for container-in-container functionality
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
    && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Add vscode user to docker group
RUN usermod -aG docker vscode

# Ensure all scripts are executable
RUN chmod +x gradlew update-models.sh

# Set up the project
# We'll use a conditional approach to handle both initial build and subsequent runs
# This avoids rebuilding when container is restarted

# Create a marker file to track if initialization is needed
RUN echo "Initial setup required" > /tmp/needs_setup

# When the container starts, run this script
COPY .devcontainer/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set the entry point
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]