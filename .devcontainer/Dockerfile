#===============================================================================
# DocumentReader Web Java Client - Development Container Definition
#===============================================================================
# Original Author: Regula Forensics Inc. (base repository)
# Dev Container Implementation: Dean Luus
# Email: dean.luus@jdconsulting.com
# GitHub: https://github.com/DeanLuus
# Date: 2025/03/27
# Last updated: 2025/03/27
#===============================================================================

FROM eclipse-temurin:17-jre-alpine

# Install dependencies and setup user in one layer
RUN apk add --no-cache git docker-cli curl bash && \
    addgroup -g 1000 vscode && \
    adduser -u 1000 -G vscode -s /bin/bash -D vscode && \
    addgroup docker && \
    addgroup vscode docker

WORKDIR /workspaces/DocumentReader-web-java-client

# Setup entrypoint
COPY .devcontainer/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    echo "Initial setup required" > /tmp/needs_setup

USER vscode

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]