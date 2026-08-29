#!/bin/sh
set -eu

die() {
    echo "rdp-vnc-gateway: $*" >&2
    exit 1
}

VNC_HOST="${VNC_HOST:?VNC_HOST is required}"
VNC_PORT="${VNC_PORT:-5900}"

VNC_ADDRESS="$(getent ahostsv4 "$VNC_HOST" | awk 'NR == 1 { print $1 }')"
[ -n "$VNC_ADDRESS" ] || die "could not resolve VNC_HOST: $VNC_HOST"
VNC_ADDRESS="::ffff:$VNC_ADDRESS"

case "$VNC_PORT" in
    *[!0-9]*|'') die "VNC_PORT must be a TCP port number" ;;
esac

if [ "$VNC_PORT" -lt 1 ] || [ "$VNC_PORT" -gt 65535 ]; then
    die "VNC_PORT must be between 1 and 65535"
fi

if [ -n "${VNC_PASSWORD_FILE:-}" ]; then
    [ -r "$VNC_PASSWORD_FILE" ] || die "VNC_PASSWORD_FILE is not readable"
    VNC_PASSWORD="$(tr -d '\r\n' < "$VNC_PASSWORD_FILE")"
else
    VNC_PASSWORD="${VNC_PASSWORD:-}"
fi

# A missing or empty VNC password deliberately leaves the `password` directive
# out of xrdp.ini. That lets libvnc negotiate VNC's `None` security type with a
# passwordless VNC server. When a password is supplied, base64 protects the
# xrdp.ini parser from punctuation or spaces; it is not encryption.
VNC_PASSWORD_SETTING=""
if [ -n "$VNC_PASSWORD" ]; then
    VNC_PASSWORD_B64="$(printf %s "$VNC_PASSWORD" | base64 | tr -d '\n')"
    VNC_PASSWORD_SETTING="password={base64}$VNC_PASSWORD_B64"
fi

CERT_FILE="${XRDP_CERT_FILE:-/etc/xrdp/cert.pem}"
KEY_FILE="${XRDP_KEY_FILE:-/etc/xrdp/key.pem}"
if [ ! -s "$CERT_FILE" ] || [ ! -s "$KEY_FILE" ]; then
    umask 077
    openssl req -x509 -newkey rsa:3072 -nodes -days 365 \
        -subj "/CN=${XRDP_CERT_CN:-rdp-vnc-gateway}" \
        -keyout "$KEY_FILE" -out "$CERT_FILE" >/dev/null 2>&1
fi
chown xrdp:xrdp "$CERT_FILE" "$KEY_FILE"
chmod 0644 "$CERT_FILE"
chmod 0640 "$KEY_FILE"

cat > /etc/xrdp/xrdp.ini <<EOF
[Globals]
port=3389
fork=true
security_layer=tls
certificate=$CERT_FILE
key_file=$KEY_FILE
tls_ciphers=HIGH:!aNULL:!MD5
crypt_level=high
bitmap_cache=true
bitmap_compression=true
bulk_compression=true
max_bpp=32
autorun=vnc-gateway

[Logging]
LogFile=/var/log/xrdp/xrdp.log
LogLevel=INFO
EnableSyslog=false

[Channels]
rdpdr=true
rdpsnd=true
drdynvc=true
cliprdr=true

[vnc-gateway]
name=VNC gateway
lib=libvnc.so
ip=$VNC_ADDRESS
port=$VNC_PORT
username=na
$VNC_PASSWORD_SETTING
EOF

mkdir -p /var/run/xrdp /var/log/xrdp
chown -R xrdp:xrdp /var/run/xrdp /var/log/xrdp

# The VNC backend does not need xrdp-sesman. xrdp handles each RDP connection
# and opens its own VNC connection using the configured backend above.
exec /usr/sbin/xrdp --nodaemon
