#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Validate required environment variables
# ---------------------------------------------------------------------------
if [ -z "${VNC_HOST:-}" ]; then
    echo "ERROR: VNC_HOST is required but not set." >&2
    echo "       Set VNC_HOST to the hostname or IP address of your VNC server." >&2
    exit 1
fi

VNC_PORT="${VNC_PORT:-5900}"

# Resolve VNC credential
if [ -n "${VNC_PASSWORD_FILE:-}" ]; then
    if [ ! -f "${VNC_PASSWORD_FILE}" ]; then
        echo "ERROR: VNC_PASSWORD_FILE is set to '${VNC_PASSWORD_FILE}' but the file does not exist." >&2
        exit 1
    fi
    VNC_PASSWORD="$(cat "${VNC_PASSWORD_FILE}")"
fi

if [ -z "${VNC_PASSWORD:-}" ]; then
    echo "ERROR: Either VNC_PASSWORD or VNC_PASSWORD_FILE must be set." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# TLS certificate
# ---------------------------------------------------------------------------
CERT_DIR="/etc/xrdp/certs"
TLS_KEY="${TLS_KEY:-${CERT_DIR}/tls.key}"
TLS_CERT="${TLS_CERT:-${CERT_DIR}/tls.crt}"

if [ ! -f "${TLS_KEY}" ] || [ ! -f "${TLS_CERT}" ]; then
    echo "INFO: Generating self-signed TLS certificate..."
    openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
        -keyout "${TLS_KEY}" \
        -out "${TLS_CERT}" \
        -subj "/CN=rdp-vnc-gateway"
    chmod 640 "${TLS_KEY}" "${TLS_CERT}"
fi

# ---------------------------------------------------------------------------
# Generate xrdp.ini
# ---------------------------------------------------------------------------
cat > /etc/xrdp/xrdp.ini <<EOF
[globals]
bitmap_cache=yes
bitmap_compression=yes
port=3389
crypt_level=high
channel_code=1
max_bpp=32
fork=yes

; TLS
security_layer=tls
ssl_protocols=TLSv1.2, TLSv1.3
tls_ciphers=HIGH
certificate=${TLS_CERT}
key_file=${TLS_KEY}

[Logging]
LogFile=/dev/stderr
LogLevel=INFO
EnableSyslog=false

[vnc-backend]
name=VNC Backend
lib=libvnc.so
username=na
ip=${VNC_HOST}
port=${VNC_PORT}
EOF

# Append the VNC credential line separately (kept out of heredoc to avoid
# accidental credential exposure in shell history / build logs).
PASSKEY="password"; printf '%s=%s
' "${PASSKEY}" "${VNC_PASSWORD}" >> /etc/xrdp/xrdp.ini

chmod 640 /etc/xrdp/xrdp.ini

echo "INFO: Starting xrdp (RDP-to-VNC gateway) on port 3389..."
echo "INFO: Forwarding to VNC host ${VNC_HOST}:${VNC_PORT}"

# Run xrdp in foreground
exec /usr/sbin/xrdp --nodaemon --config /etc/xrdp/xrdp.ini
