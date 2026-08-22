FROM alpine AS fetcher
RUN apk add wget tar
RUN arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/ > /tmp/arch

FROM fetcher AS litestream
RUN arch=$(cat /tmp/arch) &&\
    wget https://github.com/benbjohnson/litestream/releases/download/v0.3.13/litestream-v0.3.13-linux-${arch}.tar.gz && \
    tar -xf litestream-v0.3.13-linux-${arch}.tar.gz

FROM fetcher AS geesefs
RUN arch=$(cat /tmp/arch) &&\
    wget https://github.com/yandex-cloud/geesefs/releases/download/v0.41.3/geesefs-linux-${arch} -O geesefs && \
    chmod +x geesefs

FROM ghcr.io/dani-garcia/vaultwarden:1.37.2-alpine
RUN apk add age fuse jq openssl
COPY --from=litestream /litestream /usr/bin/litestream
COPY --from=geesefs /geesefs /usr/bin/geesefs
COPY --from=minio/mc:RELEASE.2024-10-02T08-27-28Z /usr/bin/mc /usr/bin/mc
COPY lib.sh /lib.sh
COPY litestream-entrypoint.sh /
COPY entrypoint.sh .

# Make Vaultwarden listen on port 8080.
ENV ROCKET_PORT=8080

ENTRYPOINT [ "/bin/sh", "/entrypoint.sh" ]
