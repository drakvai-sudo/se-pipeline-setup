#!/usr/bin/env bash
set -e

cd "$(cd "$(dirname "$0")" && pwd)"

echo "============================================"
echo " se-pipeline -- Update"
echo "============================================"
echo ""

if ! docker info &>/dev/null; then
    echo "ERROR: Docker is not running."
    echo "Please start Docker Desktop and re-run: ./update.sh"
    exit 1
fi

echo "Pulling latest image..."
echo ""
docker compose pull
echo ""

echo "Restarting services with new image..."
echo ""
docker compose up -d --force-recreate
echo ""

echo "Waiting for API to be ready..."
API_READY=
for i in $(seq 1 20); do
    sleep 4
    if curl -sf http://localhost:8000/docs >/dev/null 2>&1; then
        API_READY=1
        break
    fi
done

if [ -z "$API_READY" ]; then
    echo "[WARN] API did not respond within 80s. Check: docker compose ps"
else
    echo "[OK] API is ready."
fi
echo ""

# ── Update CLI binary from GitHub Releases ────
echo ""
echo "Updating se-pipeline CLI binary..."
echo ""

OS="$(uname -s)"
ARCH="$(uname -m)"

if [ "$OS" = "Darwin" ]; then
    [ "$ARCH" = "arm64" ] && CLI_ASSET="se-pipeline-darwin-arm64" || CLI_ASSET="se-pipeline-darwin-x86_64"
elif [ "$OS" = "Linux" ]; then
    CLI_ASSET="se-pipeline-linux"
else
    CLI_ASSET=""
fi

if [ -n "$CLI_ASSET" ]; then
    CLI_BIN="$HOME/.local/bin/se-pipeline"
    CLI_URL="https://github.com/drakvai-sudo/se-pipeline-releases/releases/latest/download/$CLI_ASSET"
    mkdir -p "$HOME/.local/bin"
    if curl -fsSL "$CLI_URL" -o "$CLI_BIN"; then
        chmod +x "$CLI_BIN"
        echo "[OK] CLI updated: $CLI_BIN"
    else
        echo "[WARN] CLI update failed -- previous binary unchanged."
    fi
else
    echo "[WARN] Unsupported OS: $OS -- CLI not updated."
fi
echo ""

echo "============================================"
echo " Update complete!"
echo "============================================"
echo ""
docker compose ps
echo ""
