FROM eclipse-temurin:17-jre-alpine

# Install minimal dependencies
RUN apk add --no-cache git docker-cli curl bash

# Create 'vscode' user with Docker access
RUN addgroup -g 1000 vscode \
    && adduser -u 1000 -G vscode -s /bin/bash -D vscode \
    && addgroup docker \
    && addgroup vscode docker

# Set up workspace
WORKDIR /workspaces/DocumentReader-web-java-client

# Create marker file for setup tracking
RUN echo "Initial setup required" > /tmp/needs_setup

# Setup entrypoint
COPY .devcontainer/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

USER vscode

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]