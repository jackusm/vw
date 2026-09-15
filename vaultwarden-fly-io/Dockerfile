FROM alpine:3.22@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce AS fetcher
RUN apk add --no-cache wget tar && \
    arch | sed 's/aarch64/arm64/;s/x86_64/amd64/' > /tmp/arch

FROM fetcher AS litestream
# renovate: datasource=github-releases depName=benbjohnson/litestream
ARG LITESTREAM_VERSION=0.3.13
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
FROM ghcr.io/dani-garcia/vaultwarden:1.37.2-alpine@sha256:d16a304c2476fd787634ddde2c00be8fdfa1a72539438c626ece3686b5b88ab4
RUN apk add --no-cache age fuse jq openssl
COPY --from=litestream /litestream /usr/bin/litestream
COPY --from=geesefs /geesefs /usr/bin/geesefs
COPY lib.sh /lib.sh
COPY litestream-entrypoint.sh /
COPY entrypoint.sh .

# Make Vaultwarden listen on port 8080.
ENV ROCKET_PORT=8080

ENTRYPOINT [ "/bin/sh", "/entrypoint.sh" ]
