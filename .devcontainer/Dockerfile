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
    git \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Add vscode user to docker group
RUN usermod -aG docker vscode

# Create necessary directories
RUN mkdir -p /workspaces && \
    mkdir -p /workspaces/DocumentReader-web-java-client/example/src/main/resources

# Create a marker file to track if initialization is needed
RUN echo "Initial setup required" > /tmp/needs_setup

# When the container starts, run this script
COPY .devcontainer/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set the entry point
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]