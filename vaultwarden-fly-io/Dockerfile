FROM alpine:3.24@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a AS fetcher
RUN apk add --no-cache wget tar && \
    arch | sed 's/aarch64/arm64/;s/x86_64/amd64/' > /tmp/arch

FROM fetcher AS litestream
# renovate: datasource=github-releases depName=benbjohnson/litestream
ARG LITESTREAM_VERSION=0.5.18
RUN set -eux; \
    arch=$(cat /tmp/arch); \
    wget -O litestream.tar.gz "https://github.com/benbjohnson/litestream/releases/download/v${LITESTREAM_VERSION}/litestream-v${LITESTREAM_VERSION}-linux-${arch}.tar.gz"; \
    tar -xf litestream.tar.gz

FROM fetcher AS geesefs
# renovate: datasource=github-releases depName=yandex-cloud/geesefs
ARG GEESEFS_VERSION=0.43.9
RUN set -eux; \
    arch=$(cat /tmp/arch); \
    wget -O geesefs "https://github.com/yandex-cloud/geesefs/releases/download/v${GEESEFS_VERSION}/geesefs-linux-${arch}"; \
    chmod +x geesefs

# Runs as root: GeeseFS/FUSE requires it (see mount_s3 note in entrypoint.sh).
FROM ghcr.io/dani-garcia/vaultwarden:1.37.5-alpine@sha256:bbe684a02d6b0db54256ff88eac9754f4519284a7b26314afc241fd7d0918191
RUN apk add --no-cache age fuse jq openssl
COPY --from=litestream /litestream /usr/bin/litestream
COPY --from=geesefs /geesefs /usr/bin/geesefs
COPY lib.sh /lib.sh
COPY litestream-entrypoint.sh /
COPY entrypoint.sh .

# Make Vaultwarden listen on port 8080.
ENV ROCKET_PORT=8080

ENTRYPOINT [ "/bin/sh", "/entrypoint.sh" ]
