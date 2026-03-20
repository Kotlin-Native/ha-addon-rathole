# Home Assistant Add-on: Rathole Client

[Rathole](https://github.com/rapiz1/rathole) is a lightweight and high-performance reverse proxy for NAT traversal, written in Rust. This add-on runs the **rathole client**, connecting your Home Assistant instance to a remote rathole server so you can access Home Assistant from anywhere without port forwarding.

## How it works

```
[You] --> [Rathole Server (VPS)] <--tunnel-- [Rathole Client (this add-on)] --> [Home Assistant]
```

The rathole client running inside Home Assistant establishes an outbound connection to your rathole server. The server then accepts incoming connections and forwards them through the tunnel to your Home Assistant instance.

## Prerequisites

You need a **rathole server** running on a publicly accessible machine (e.g., a VPS). The server's `server.toml` should have matching service definitions. Example:

```toml
[server]
bind_addr = "0.0.0.0:2333"
default_token = "your_secret_token_here"

[server.services.homeassistant]
type = "tcp"
bind_addr = "0.0.0.0:8080"
```

This would expose your Home Assistant on port 8080 of the server.

## Installation

1. Add this repository to your Home Assistant add-on store:
   - Go to **Settings** → **Add-ons** → **Add-on Store** → **⋮** (top right) → **Repositories**
   - Add the repository URL
2. Install the **Rathole Client** add-on
3. Configure the add-on (see below)
4. Start the add-on

## Configuration

### Required settings

| Option | Description |
|--------|-------------|
| `remote_addr` | Address of the rathole server, e.g. `your-server.com:2333` |
| `default_token` | Authentication token (must match the server) |

### Transport settings

| Option | Default | Description |
|--------|---------|-------------|
| `transport_type` | `tcp` | Transport protocol: `tcp`, `tls`, `noise`, or `websocket` |
| `tls_trusted_root` | | Path to CA certificate for TLS (relative to `/ssl` or absolute) |
| `tls_hostname` | | Expected server hostname for TLS verification |
| `noise_remote_public_key` | | Server's Noise protocol public key |
| `noise_local_private_key` | | Client's Noise protocol private key |
| `websocket_tls` | `false` | Enable TLS for WebSocket transport |

### Connection settings

| Option | Default | Description |
|--------|---------|-------------|
| `heartbeat_timeout` | `40` | Heartbeat timeout in seconds (0 to disable) |
| `retry_interval` | `1` | Retry interval in seconds when connection drops |

### Services

Each service defines a tunnel. By default, a `homeassistant` service is configured:

| Option | Description |
|--------|-------------|
| `name` | Service name (must match the server config) |
| `type` | Protocol: `tcp` or `udp` |
| `local_addr` | Local address to forward to (e.g. `homeassistant:8123`) |
| `token` | Per-service token (optional, overrides `default_token`) |
| `nodelay` | TCP no-delay flag (default: `true`) |

### Example configuration

```yaml
remote_addr: "your-vps.example.com:2333"
default_token: "a_secure_random_token"
transport_type: "tcp"
heartbeat_timeout: 40
retry_interval: 1
services:
  - name: "homeassistant"
    type: "tcp"
    local_addr: "homeassistant:8123"
    nodelay: true
```

### Multiple services

You can tunnel more than just Home Assistant:

```yaml
services:
  - name: "homeassistant"
    type: "tcp"
    local_addr: "homeassistant:8123"
    nodelay: true
  - name: "ssh"
    type: "tcp"
    local_addr: "172.30.32.1:22"
    token: "different_token_for_ssh"
    nodelay: true
```

## Accessing Home Assistant remotely

Once the add-on is running and connected to the server:

1. Open `http://your-server-address:SERVER_BIND_PORT` in your browser
2. You'll see the Home Assistant login page

For HTTPS, configure TLS on the rathole server side or place a reverse proxy (like nginx/Caddy) in front of the server's bind port.

## Troubleshooting

- **Connection refused**: Verify the server address and that the rathole server is running
- **Token mismatch**: Ensure `default_token` matches between client and server configs
- **Service not found**: Service names must match exactly between client and server
- Check the add-on logs for detailed error messages
