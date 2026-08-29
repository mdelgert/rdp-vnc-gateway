FROM debian:bookworm-slim

# Install xrdp and its VNC backend
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        xrdp \
        xorgxrdp \
        openssl \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Create the /etc/xrdp/certs directory for TLS
RUN mkdir -p /etc/xrdp/certs

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3389

ENTRYPOINT ["/entrypoint.sh"]
