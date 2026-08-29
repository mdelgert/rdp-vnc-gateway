# rdp-vnc-gateway

A production-oriented Docker project that runs **xrdp** as an RDP-to-VNC gateway.

```
Windows / macOS / Linux RDP client
        │  TCP 3389  (TLS)
        ▼
  rdp-vnc-gateway  (this container)
        │  TCP 5900  (or custom VNC_PORT)
        ▼
   Your VNC server
```

Native Microsoft Remote Desktop (mstsc) or any standards-compliant RDP client connects to the container over TLS; the container forwards the session to a configured VNC host. No VNC server or desktop environment is bundled in the image.

---

## ⚠️ Security Notice

**Do not expose TCP 3389 directly to the public internet.**  
Protect the RDP port with a VPN (WireGuard, OpenVPN, Tailscale, etc.) or a strict firewall rule that allows only trusted IP addresses.

The default `compose.yaml` binds the port to `127.0.0.1` only, which is safe for local use.

---

## Requirements

| Software | Minimum version |
|---|---|
| Docker Engine | 24.x |
| Docker Compose | v2 |

---

## Quick Start

1. **Copy the example environment file and fill in your values.**

   ```sh
   cp .env.example .env
   # edit .env
   ```

2. **Start the gateway.**

   ```sh
   docker compose up -d
   ```

3. **Connect with your RDP client** to `127.0.0.1:3389` (or the host's IP / DNS name on port 3389 when exposed behind a VPN).

---

## Configuration

All configuration is done via environment variables passed to the container.

| Variable | Required | Default | Description |
|---|---|---|---|
| `VNC_HOST` | **Yes** | — | Hostname or IP address of the VNC server to connect to |
| `VNC_PORT` | No | `5900` | TCP port of the VNC server |
| `VNC_PASSWORD` | One of these two | — | Plain-text VNC credential (avoid in production) |
| `VNC_PASSWORD_FILE` | One of these two | — | Path to a file containing the VNC credential (Docker secret / bind-mount) |
| `TLS_CERT` | No | `/etc/xrdp/certs/tls.crt` | Path inside the container to the TLS certificate |
| `TLS_KEY` | No | `/etc/xrdp/certs/tls.key` | Path inside the container to the TLS private key |

### Using a Docker Secret (recommended for production)

```yaml
secrets:
  vnc_password:
    file: ./secrets/vnc_password.txt

services:
  rdp-vnc-gateway:
    # ...
    environment:
      VNC_PASSWORD_FILE: /run/secrets/vnc_password
    secrets:
      - vnc_password
```

### Mounting your own TLS certificate

Mount your certificate and key into the container and point the environment variables at them:

```yaml
volumes:
  - ./certs/tls.crt:/certs/tls.crt:ro
  - ./certs/tls.key:/certs/tls.key:ro
environment:
  TLS_CERT: /certs/tls.crt
  TLS_KEY:  /certs/tls.key
```

If neither `TLS_CERT`/`TLS_KEY` are provided, nor files exist at the default paths, a **self-signed certificate** is generated at startup. Self-signed certificates are fine for home-lab or VPN-only use, but RDP clients will show a certificate warning on first connection.

---

## Windows mstsc Keyboard Tips

When connecting with **mstsc** (Remote Desktop Connection) in full-screen mode and you want Windows-key shortcuts (e.g. Win+D, Win+L) to be sent to the *remote* VNC host instead of your local machine:

1. Open **Remote Desktop Connection** (mstsc).
2. Click **Show Options → Local Resources** tab.
3. Under **Keyboard**, change *Apply Windows key combinations* to **"On the remote computer"**.
4. Connect in **full-screen** mode.

---

## Building manually

```sh
docker build -t rdp-vnc-gateway .
docker run --rm \
  -e VNC_HOST=192.168.1.50 \
  -e VNC_PORT=5900 \
  -e VNC_PASSWORD=mysecret \
  -p 127.0.0.1:3389:3389 \
  rdp-vnc-gateway
```

---

## How it works

1. The container installs `xrdp` and its `libvnc.so` backend from the Debian package repository — no custom builds needed.
2. At startup, `entrypoint.sh`:
   - Validates `VNC_HOST` and the VNC credential.
   - Generates a self-signed TLS certificate if one is not mounted.
   - Writes `/etc/xrdp/xrdp.ini` with a single `[vnc-backend]` section pointing at the target VNC host.
   - Executes `xrdp` in the foreground so Docker receives signals and logs go to stdout/stderr.
3. The RDP client connects to port 3389 and xrdp proxies the session to the VNC host transparently.

---

## License

MIT — see [LICENSE](LICENSE).
