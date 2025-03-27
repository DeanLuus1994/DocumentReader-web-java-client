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

ARG JAVA_VERSION=17

FROM eclipse-temurin:${JAVA_VERSION}-jdk-alpine

# Accept build arguments
ARG USER_NAME=vscode
ARG USER_ID=1000
ARG GROUP_ID=1000

# Install dependencies and setup user in one layer
RUN apk add --no-cache git docker-cli curl bash procps coreutils shadow sudo gradle && \
    addgroup -g ${GROUP_ID} ${USER_NAME} && \
    adduser -u ${USER_ID} -G ${USER_NAME} -s /bin/bash -D ${USER_NAME} && \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER_NAME} && \
    chmod 0440 /etc/sudoers.d/${USER_NAME} && \
    addgroup docker && \
    addgroup ${USER_NAME} docker

WORKDIR /workspaces/DocumentReader-web-java-client

# Setup entrypoint with proper permissions
COPY .devcontainer/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chown ${USER_NAME}:${USER_NAME} /usr/local/bin/entrypoint.sh && \
    echo "Initial setup required" > /tmp/needs_setup && \
    chown ${USER_NAME}:${USER_NAME} /tmp/needs_setup

USER ${USER_NAME}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]