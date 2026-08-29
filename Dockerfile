FROM debian:bookworm-slim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        openssl \
        xrdp \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/rdp-vnc-gateway

RUN chmod 0755 /usr/local/bin/rdp-vnc-gateway \
    && mkdir -p /var/run/xrdp /var/log/xrdp \
    && chown -R xrdp:xrdp /var/run/xrdp /var/log/xrdp

EXPOSE 3389

ENTRYPOINT ["/usr/local/bin/rdp-vnc-gateway"]
