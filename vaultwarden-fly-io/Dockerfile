FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS fetcher
RUN apk add --no-cache wget tar && \
    arch | sed 's/aarch64/arm64/;s/x86_64/amd64/' > /tmp/arch

FROM fetcher AS litestream
# renovate: datasource=github-releases depName=benbjohnson/litestream
ARG LITESTREAM_VERSION=0.5.17
RUN set -eux; \
    arch=$(cat /tmp/arch); \
    wget -O litestream.tar.gz "https://github.com/benbjohnson/litestream/releases/download/v${LITESTREAM_VERSION}/litestream-v${LITESTREAM_VERSION}-linux-${arch}.tar.gz"; \
    tar -xf litestream.tar.gz

FROM fetcher AS geesefs
# renovate: datasource=github-releases depName=yandex-cloud/geesefs
ARG GEESEFS_VERSION=0.41.3
RUN set -eux; \
    arch=$(cat /tmp/arch); \
    wget -O geesefs "https://github.com/yandex-cloud/geesefs/releases/download/v${GEESEFS_VERSION}/geesefs-linux-${arch}"; \
    chmod +x geesefs

# Runs as root: GeeseFS/FUSE requires it (see mount_s3 note in entrypoint.sh).
FROM ghcr.io/dani-garcia/vaultwarden:1.37.3-alpine@sha256:9a905c5cf5df61bb827da3805e160170741c0b53b0c63bb07e1afd3d2e21b1c8
RUN apk add --no-cache age fuse jq openssl
COPY --from=litestream /litestream /usr/bin/litestream
COPY --from=geesefs /geesefs /usr/bin/geesefs
COPY lib.sh /lib.sh
COPY litestream-entrypoint.sh /
COPY entrypoint.sh .

# Make Vaultwarden listen on port 8080.
ENV ROCKET_PORT=8080

ENTRYPOINT [ "/bin/sh", "/entrypoint.sh" ]
