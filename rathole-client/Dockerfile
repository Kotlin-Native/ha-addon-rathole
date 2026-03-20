ARG BUILD_FROM
FROM ${BUILD_FROM}

ARG RATHOLE_VERSION
ARG BUILD_ARCH

# Install dependencies for downloading and running rathole
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    unzip

# Download rathole binary based on architecture
RUN set -eux; \
    case "${BUILD_ARCH}" in \
        amd64)   ARCH="x86_64-unknown-linux-musl" ;; \
        aarch64) ARCH="aarch64-unknown-linux-musl" ;; \
        armv7)   ARCH="armv7-unknown-linux-musleabihf" ;; \
        *)       echo "Unsupported architecture: ${BUILD_ARCH}" && exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/rapiz1/rathole/releases/download/v${RATHOLE_VERSION}/rathole-${ARCH}.zip" \
        -o /tmp/rathole.zip; \
    unzip /tmp/rathole.zip -d /tmp/rathole; \
    mv /tmp/rathole/rathole /usr/local/bin/rathole; \
    chmod +x /usr/local/bin/rathole; \
    rm -rf /tmp/rathole /tmp/rathole.zip

COPY rootfs /
