#===============================================================================
# DocumentReader Web Java Client - Enterprise Development Container
#===============================================================================
# Original Author: Regula Forensics Inc. (base repository)
# Dev Container Implementation: Dean Luus
# Email: dean.luus@jdconsulting.com
# GitHub: https://github.com/DeanLuus
# Date: 2025/03/27
# Last updated: 2025/03/27
#===============================================================================

FROM mcr.microsoft.com/vscode/devcontainers/java:17-bullseye

LABEL maintainer="Dean Luus <dean.luus@jdconsulting.com>"
LABEL version="1.0.0"
LABEL description="Enterprise-grade development container for DocumentReader Web Java Client"

# Accept build arguments with sensible defaults
ARG USER_NAME=vscode
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG GRADLE_VERSION=7.6.1
ARG MAVEN_VERSION=3.9.2
ARG DOCKER_VERSION=20.10.21
ARG NODE_VERSION=16.19.0

# Set environment variables for build tools and locale
ENV GRADLE_HOME=/opt/gradle \
    MAVEN_HOME=/opt/maven \
    GRADLE_USER_HOME=/home/${USER_NAME}/.gradle \
    MAVEN_CONFIG=/home/${USER_NAME}/.m2 \
    JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF8 -XX:+UseContainerSupport -XX:MaxRAMPercentage=80.0" \
    TERM="xterm-256color" \
    COLORTERM="truecolor" \
    DEBIAN_FRONTEND="noninteractive" \
    LANG="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8" \
    TZ="UTC" \
    HOME="/home/${USER_NAME}" \
    SHELL="/bin/bash" \
    EDITOR="vi" \
    PATH="/home/${USER_NAME}/.local/bin:/opt/gradle/bin:/opt/maven/bin:${PATH}"

# Install enterprise-grade dependencies and development tools
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y install --no-install-recommends \
    docker.io \
    docker-compose \
    python3 \
    python3-pip \
    jq \
    unzip \
    zip \
    gnupg2 \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    openssh-client \
    git-lfs \
    vim \
    less \
    procps \
    net-tools \
    dos2unix \
    curl \
    wget \
    dnsutils \
    iproute2 \
    iptables \
    iputils-ping \
    locales \
    strace \
    lsof \
    tzdata \
    sudo \
    tini \
    bash-completion \
    fontconfig \
    && locale-gen en_US.UTF-8 \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Set up timezone 
RUN ln -fs /usr/share/zoneinfo/UTC /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata

# Install and configure reliable Gradle version with checksum verification
RUN mkdir -p ${GRADLE_HOME} && \
    GRADLE_DOWNLOAD_URL="https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" && \
    GRADLE_DOWNLOAD_SHA256=$(curl -sSL "${GRADLE_DOWNLOAD_URL}.sha256") && \
    curl -sSL "${GRADLE_DOWNLOAD_URL}" -o gradle.zip && \
    echo "${GRADLE_DOWNLOAD_SHA256} gradle.zip" | sha256sum --check - && \
    unzip -d ${GRADLE_HOME} gradle.zip && \
    rm gradle.zip && \
    ln -s "${GRADLE_HOME}/gradle-${GRADLE_VERSION}/bin/gradle" /usr/local/bin/gradle && \
    mkdir -p ${GRADLE_USER_HOME} && \
    chown -R ${USER_NAME}:${USER_NAME} ${GRADLE_USER_HOME}

# Install and configure Maven with checksum verification
RUN mkdir -p ${MAVEN_HOME} && \
    MAVEN_DOWNLOAD_URL="https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" && \
    MAVEN_DOWNLOAD_SHA512=$(curl -sSL "${MAVEN_DOWNLOAD_URL}.sha512") && \
    curl -sSL "${MAVEN_DOWNLOAD_URL}" -o maven.tar.gz && \
    echo "${MAVEN_DOWNLOAD_SHA512} maven.tar.gz" | sha512sum --check - && \
    tar -xzf maven.tar.gz -C ${MAVEN_HOME} --strip-components=1 && \
    rm maven.tar.gz && \
    ln -s "${MAVEN_HOME}/bin/mvn" /usr/local/bin/mvn && \
    mkdir -p ${MAVEN_CONFIG} && \
    chown -R ${USER_NAME}:${USER_NAME} ${MAVEN_CONFIG}

# Add docker group and setup permissions
RUN getent group docker || groupadd docker && \
    usermod -aG docker ${USER_NAME} && \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER_NAME} && \
    chmod 0440 /etc/sudoers.d/${USER_NAME}

# Add additional health monitoring tools
RUN pip3 install --no-cache-dir glances httpie virtualenv

# Create workspace directory with proper permissions
WORKDIR /workspaces/DocumentReader-web-java-client
RUN mkdir -p /workspaces && \
    chown ${USER_NAME}:${USER_NAME} /workspaces && \
    mkdir -p /tmp/devcontainer-logs && \
    chown ${USER_NAME}:${USER_NAME} /tmp/devcontainer-logs

# Setup entrypoint with proper permissions
COPY .devcontainer/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chown ${USER_NAME}:${USER_NAME} /usr/local/bin/entrypoint.sh && \
    echo "Initial setup required" > /tmp/needs_setup && \
    chown ${USER_NAME}:${USER_NAME} /tmp/needs_setup

# Create pre-commit hook template directory
RUN mkdir -p /etc/git-templates/hooks && \
    chmod +x /etc/git-templates/hooks && \
    git config --system init.templateDir /etc/git-templates/hooks

# Configure global git settings for better enterprise compliance
RUN git config --system core.autocrlf input && \
    git config --system pull.rebase true && \
    git config --system fetch.prune true && \
    git config --system push.default simple && \
    git config --system core.longpaths true && \
    git config --system core.fileMode false

# Create health check script
RUN echo '#!/bin/bash\necho "Container is healthy" > /tmp/container-health\ntouch -d "$(date)" /tmp/container-health' > /usr/local/bin/container-healthcheck && \
    chmod +x /usr/local/bin/container-healthcheck && \
    echo "*/1 * * * * /usr/local/bin/container-healthcheck" | crontab -

# Switch to non-root user
USER ${USER_NAME}

# Configure user-level Gradle and Maven settings
COPY --chown=${USER_NAME}:${USER_NAME} .devcontainer/gradle.properties ${GRADLE_USER_HOME}/gradle.properties
COPY --chown=${USER_NAME}:${USER_NAME} .devcontainer/settings.xml ${MAVEN_CONFIG}/settings.xml

# Set up bash configuration for better developer experience
RUN echo 'export PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$ "' >> ~/.bashrc && \
    echo 'export HISTSIZE=5000' >> ~/.bashrc && \
    echo 'export HISTFILESIZE=10000' >> ~/.bashrc && \
    echo 'export HISTCONTROL=ignoreboth:erasedups' >> ~/.bashrc && \
    echo 'shopt -s histappend' >> ~/.bashrc && \
    echo 'alias ll="ls -la"' >> ~/.bashrc && \
    echo 'alias gs="git status"' >> ~/.bashrc && \
    echo 'alias gc="git commit"' >> ~/.bashrc && \
    echo 'alias gp="git pull"' >> ~/.bashrc && \
    echo 'alias gd="git diff"' >> ~/.bashrc

# Pre-warm package caches
RUN mkdir -p /tmp/warmup && \
    cd /tmp/warmup && \
    echo "public class Warmup { public static void main(String[] args) { System.out.println(\"Warming up build tools\"); } }" > Warmup.java && \
    javac Warmup.java && \
    java Warmup && \
    echo "task empty {}" > build.gradle && \
    gradle --quiet tasks && \
    echo "<project><modelVersion>4.0.0</modelVersion><groupId>com.warmup</groupId><artifactId>warmup</artifactId><version>1.0</version></project>" > pom.xml && \
    mvn --quiet validate && \
    cd / && \
    rm -rf /tmp/warmup

# Create directory for custom scripts
RUN mkdir -p ~/scripts && \
    echo '#!/bin/bash\necho "Running environment diagnosis..."\njava -version\ngradle --version\nmvn --version\ndocker --version\ndocker-compose --version\npython3 --version\n' > ~/scripts/diagnose.sh && \
    chmod +x ~/scripts/diagnose.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]