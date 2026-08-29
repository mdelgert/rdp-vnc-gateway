# RDP-to-VNC Gateway

This container runs xrdp's built-in VNC backend. It lets a native RDP client
connect to an existing VNC server:

```text
Microsoft Remote Desktop (mstsc) -> RDP/TLS -> this gateway -> VNC -> host
```

The gateway is intended for one configured VNC target per container. It does
not start a desktop or VNC server of its own.

## Start it

1. In `compose.yaml`, replace `192.0.2.10` with the address of your VNC host
   and set its VNC password.
2. Start the gateway:

   ```sh
   docker compose up -d --build
   ```

3. Open **Remote Desktop Connection** (`mstsc.exe`) and connect to the gateway
   address and port 3389.

   xrdp displays its small login screen before opening the configured VNC
   target. The values typed into that screen are not VNC credentials: the VNC
   password comes from the container configuration. Any non-empty username and
   password can be used there unless you restrict access at the network layer.

4. In `mstsc` choose **Show Options → Local Resources → Keyboard → On the
   remote computer**. In full-screen mode, the Windows key and Windows-key
   shortcuts are then sent through RDP to the VNC host.

## Environment variables

| Variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `VNC_HOST` | Yes | — | DNS name or IP address of the target VNC server. |
| `VNC_PORT` | No | `5900` | Target VNC TCP port. |
| `VNC_PASSWORD` | No | — | Target VNC password. Omit for a passwordless VNC server. |
| `VNC_PASSWORD_FILE` | No | — | Read the target VNC password from a file; preferred over an environment variable. |
| `XRDP_CERT_CN` | No | `rdp-vnc-gateway` | Common name for the self-signed TLS certificate generated on first start. |
| `XRDP_CERT_FILE` / `XRDP_KEY_FILE` | No | `/etc/xrdp/cert.pem`, `/etc/xrdp/key.pem` | Paths for a certificate/key pair you provide. |

`VNC_PASSWORD_FILE` takes precedence over `VNC_PASSWORD`. If neither value is
provided (or the supplied value is empty), the gateway requests VNC's `None`
authentication mode. The password's base64 representation in the xrdp
configuration is encoding, not encryption; use a mounted secret file in real
deployments.

## Security

Do not publish TCP/3389 to the public internet. xrdp's login UI only chooses
the fixed connection and does not add meaningful gateway authentication in this
configuration. Restrict access with a VPN (such as Tailscale or WireGuard), a
firewall/source-IP allowlist, or an authenticated network proxy. TLS is enabled
between the RDP client and the gateway; replace the generated self-signed
certificate if clients need to verify its identity.

The target VNC connection remains governed by the VNC server's authentication
and encryption capabilities. Prefer a VNC server accessed over a private
network or tunnel.

## Secret-file example

Create a local file named `vnc_password.txt` containing only the VNC password,
then uncomment the `secrets` lines in `compose.yaml` and remove
`VNC_PASSWORD`. The file is excluded from Docker build context by
`.dockerignore`.

## Notes

- This converts the display and input protocols. It does not add VNC features
  that the VNC server lacks.
- Clipboard support depends on the VNC target and xrdp's VNC backend.
- One container per VNC destination keeps the routing and firewalling simple.

docker network create rdp-vnc