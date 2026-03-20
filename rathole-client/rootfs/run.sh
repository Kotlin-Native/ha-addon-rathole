#!/usr/bin/env bash
# shellcheck shell=bash
set -e

CONFIG_PATH="/data/options.json"
TOML_PATH="/data/client.toml"

###############################################################################
# Read add-on options
###############################################################################
REMOTE_ADDR=$(jq -r '.remote_addr' "$CONFIG_PATH")
DEFAULT_TOKEN=$(jq -r '.default_token' "$CONFIG_PATH")
TRANSPORT_TYPE=$(jq -r '.transport_type' "$CONFIG_PATH")
TLS_TRUSTED_ROOT=$(jq -r '.tls_trusted_root // ""' "$CONFIG_PATH")
TLS_HOSTNAME=$(jq -r '.tls_hostname // ""' "$CONFIG_PATH")
NOISE_REMOTE_PUB=$(jq -r '.noise_remote_public_key // ""' "$CONFIG_PATH")
NOISE_LOCAL_PRIV=$(jq -r '.noise_local_private_key // ""' "$CONFIG_PATH")
WEBSOCKET_TLS=$(jq -r '.websocket_tls // false' "$CONFIG_PATH")
HEARTBEAT_TIMEOUT=$(jq -r '.heartbeat_timeout // 40' "$CONFIG_PATH")
RETRY_INTERVAL=$(jq -r '.retry_interval // 1' "$CONFIG_PATH")

###############################################################################
# Validate required fields
###############################################################################
if [ -z "$REMOTE_ADDR" ] || [ "$REMOTE_ADDR" = "null" ]; then
    echo "[ERROR] remote_addr is required. Set the rathole server address in the add-on configuration."
    exit 1
fi

if [ -z "$DEFAULT_TOKEN" ] || [ "$DEFAULT_TOKEN" = "null" ]; then
    echo "[ERROR] default_token is required. Set the authentication token in the add-on configuration."
    exit 1
fi

###############################################################################
# Build client.toml
###############################################################################
echo "[INFO] Generating client.toml ..."

cat > "$TOML_PATH" <<EOF
[client]
remote_addr = "${REMOTE_ADDR}"
default_token = "${DEFAULT_TOKEN}"
heartbeat_timeout = ${HEARTBEAT_TIMEOUT}
retry_interval = ${RETRY_INTERVAL}
EOF

# --- Transport section -------------------------------------------------------
if [ "$TRANSPORT_TYPE" != "tcp" ]; then
    cat >> "$TOML_PATH" <<EOF

[client.transport]
type = "${TRANSPORT_TYPE}"
EOF
fi

# TLS transport
if [ "$TRANSPORT_TYPE" = "tls" ]; then
    cat >> "$TOML_PATH" <<EOF

[client.transport.tls]
EOF
    if [ -n "$TLS_TRUSTED_ROOT" ] && [ "$TLS_TRUSTED_ROOT" != "null" ]; then
        # If the path doesn't start with /, assume it's relative to /ssl
        if [[ "$TLS_TRUSTED_ROOT" != /* ]]; then
            TLS_TRUSTED_ROOT="/ssl/${TLS_TRUSTED_ROOT}"
        fi
        echo "trusted_root = \"${TLS_TRUSTED_ROOT}\"" >> "$TOML_PATH"
    fi
    if [ -n "$TLS_HOSTNAME" ] && [ "$TLS_HOSTNAME" != "null" ]; then
        echo "hostname = \"${TLS_HOSTNAME}\"" >> "$TOML_PATH"
    fi
fi

# Noise transport
if [ "$TRANSPORT_TYPE" = "noise" ]; then
    cat >> "$TOML_PATH" <<EOF

[client.transport.noise]
EOF
    if [ -n "$NOISE_REMOTE_PUB" ] && [ "$NOISE_REMOTE_PUB" != "null" ]; then
        echo "remote_public_key = \"${NOISE_REMOTE_PUB}\"" >> "$TOML_PATH"
    fi
    if [ -n "$NOISE_LOCAL_PRIV" ] && [ "$NOISE_LOCAL_PRIV" != "null" ]; then
        echo "local_private_key = \"${NOISE_LOCAL_PRIV}\"" >> "$TOML_PATH"
    fi
fi

# WebSocket transport
if [ "$TRANSPORT_TYPE" = "websocket" ]; then
    if [ "$WEBSOCKET_TLS" = "true" ]; then
        cat >> "$TOML_PATH" <<EOF

[client.transport.websocket]
tls = true
EOF
    fi
fi

# --- Services section --------------------------------------------------------
SERVICE_COUNT=$(jq '.services | length' "$CONFIG_PATH")

if [ "$SERVICE_COUNT" -eq 0 ]; then
    echo "[WARN] No services configured. Add at least one service to tunnel."
fi

for i in $(seq 0 $((SERVICE_COUNT - 1))); do
    SVC_NAME=$(jq -r ".services[$i].name" "$CONFIG_PATH")
    SVC_TYPE=$(jq -r ".services[$i].type" "$CONFIG_PATH")
    SVC_LOCAL=$(jq -r ".services[$i].local_addr" "$CONFIG_PATH")
    SVC_TOKEN=$(jq -r ".services[$i].token // \"\"" "$CONFIG_PATH")
    SVC_NODELAY=$(jq -r ".services[$i].nodelay // \"true\"" "$CONFIG_PATH")

    cat >> "$TOML_PATH" <<EOF

[client.services.${SVC_NAME}]
type = "${SVC_TYPE}"
local_addr = "${SVC_LOCAL}"
EOF

    if [ -n "$SVC_TOKEN" ] && [ "$SVC_TOKEN" != "null" ] && [ "$SVC_TOKEN" != "" ]; then
        echo "token = \"${SVC_TOKEN}\"" >> "$TOML_PATH"
    fi

    if [ "$SVC_NODELAY" = "true" ]; then
        echo "nodelay = true" >> "$TOML_PATH"
    fi
done

###############################################################################
# Display generated configuration (mask tokens)
###############################################################################
echo "[INFO] Generated client.toml:"
echo "------------------------------------"
sed -E 's/(token *= *")([^"]+)(")/\1***\3/g; s/(default_token *= *")([^"]+)(")/\1***\3/g; s/(local_private_key *= *")([^"]+)(")/\1***\3/g' "$TOML_PATH"
echo "------------------------------------"

###############################################################################
# Start rathole client
###############################################################################
echo "[INFO] Starting rathole client ..."
exec /usr/local/bin/rathole "$TOML_PATH"
