# syntax=docker/dockerfile:1.4
# filepath: /workspaces/DocumentReader-web-java-client/.devcontainer/Dockerfile

FROM mcr.microsoft.com/devcontainers/java:17 AS build
WORKDIR /workspace

# Configure Gradle user home and ensure its directory exists in the builder stage
ENV GRADLE_USER_HOME=/tmp/gradle-user-home
RUN mkdir -p ${GRADLE_USER_HOME}

# Copy Gradle wrapper and build scripts separately to leverage caching
COPY gradlew .
COPY gradle gradle
COPY build.gradle settings.gradle ./
RUN chmod +x gradlew

# Pre-cache Gradle dependencies (inline caching)  
RUN --mount=type=cache,target=/home/vscode/.gradle/caches \
    --mount=type=cache,target=/home/vscode/.gradle/wrapper \
    ./gradlew --no-daemon --quiet dependencies || true

# Copy the remaining project files, including scripts
COPY . .

# Ensure scripts are executable
RUN chmod +x ./update-models.sh ./setup-and-test-regula.sh

# 1) Generate the models during the build  
RUN --mount=type=cache,target=/home/vscode/.gradle/caches \
    --mount=type=cache,target=/home/vscode/.gradle/wrapper \
    ./update-models.sh

# 2) Build the project (skipping tests here so we can run them separately)
RUN --mount=type=cache,target=/home/vscode/.gradle/caches \
    --mount=type=cache,target=/home/vscode/.gradle/wrapper \
    ./gradlew --no-daemon build -x test

# 3) Run all tests (including the example and comprehensive tests)
RUN --mount=type=cache,target=/home/vscode/.gradle/caches \
    --mount=type=cache,target=/home/vscode/.gradle/wrapper \
    ./setup-and-test-regula.sh

# ----------------------------------------------------------------------------
FROM mcr.microsoft.com/devcontainers/java:17
WORKDIR /workspace

# Recreate Gradle user home in final image
ENV GRADLE_USER_HOME=/tmp/gradle-user-home
RUN mkdir -p ${GRADLE_USER_HOME}

# Copy the entire built workspace from the builder stage
COPY --from=build /workspace /workspace

# Final container just keeps running after everything is provisioned
CMD ["sleep", "infinity"]