#!/usr/bin/env bash
set -e

# Always run from the directory where setup.sh lives
SETUP_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SETUP_DIR"

echo "============================================"
echo " se-pipeline -- Setup"
echo "============================================"
echo ""

# ── 1. Check Docker ──────────────────────────────
if ! command -v docker &>/dev/null; then
    echo "ERROR: Docker not found on this machine."
    echo ""
    echo "Install Docker Desktop from:"
    echo "  https://www.docker.com/products/docker-desktop/"
    echo "Then start Docker Desktop and re-run: ./setup.sh"
    exit 1
fi
echo "[OK] Docker found."

if ! docker info &>/dev/null; then
    echo ""
    echo "ERROR: Docker Desktop is installed but not running."
    echo ""
    echo "Please start Docker Desktop, wait until it is ready,"
    echo "then re-run: ./setup.sh"
    exit 1
fi
echo "[OK] Docker is running."
echo ""

# ── 2. Create .env if it does not exist ──────────
if [ ! -f ".env" ]; then
    echo "Creating .env from template..."
    cp ".env.example" ".env"
    echo "[OK] .env created."
else
    echo "[OK] .env already exists -- skipping template copy."
fi
echo ""

# ── 3. Pull latest image ─────────────────────────
echo "Pulling latest se-pipeline image..."
echo "This may take several minutes on first run."
echo ""
docker compose pull
echo ""

# ── 4. Start services ────────────────────────────
echo "Starting services..."
echo ""
docker compose up -d
echo ""

# ── 5. Wait for API to be ready ──────────────────
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
    echo ""
    echo "[WARN] API did not respond within 80s."
    echo "       Services may still be starting. Check: docker compose ps"
    echo "       Set your API key later with:"
    echo "         se-pipeline config set GROQ_API_KEY gsk_..."
    echo ""
else
    echo "[OK] API is ready."
    echo ""
    echo "Service status:"
    docker compose ps
    echo ""
fi

# ── 6. Configure GROQ API key ─────────────────────
echo "============================================"
echo " Configuration"
echo "============================================"
echo ""
echo "You need a free Groq API key to run the pipeline."
echo "Get one at: https://console.groq.com"
echo ""
echo "You can also edit .env directly in this folder"
echo "or run: se-pipeline config set GROQ_API_KEY gsk_..."
echo ""
read -r -p "Enter your Groq API key (press Enter to skip for now): " GROQ_KEY
if [ -n "$GROQ_KEY" ]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s/GROQ_API_KEY=.*/GROQ_API_KEY=$GROQ_KEY/" .env
    else
        sed -i "s/GROQ_API_KEY=.*/GROQ_API_KEY=$GROQ_KEY/" .env
    fi
    echo "[OK] Groq API key saved to .env"
else
    echo "[SKIP] No key entered. Set it later with:"
    echo "  se-pipeline config set GROQ_API_KEY gsk_..."
fi
echo ""

# ── 7. Install CLI binary ────────────────────────
echo "============================================"
echo " Installing se-pipeline CLI"
echo "============================================"
echo ""
echo "Downloading se-pipeline CLI binary from GitHub Releases..."
echo ""

CLI_DIR="$HOME/.local/bin"
mkdir -p "$CLI_DIR"

OS="$(uname -s)"
ARCH="$(uname -m)"

if [ "$OS" = "Darwin" ]; then
    if [ "$ARCH" = "arm64" ]; then
        CLI_ASSET="se-pipeline-darwin-arm64"
    else
        CLI_ASSET="se-pipeline-darwin-x86_64"
    fi
elif [ "$OS" = "Linux" ]; then
    CLI_ASSET="se-pipeline-linux"
else
    echo "[WARN] Unsupported OS: $OS. Download manually from:"
    echo "       https://github.com/drakvai-sudo/se-pipeline-releases/releases"
    CLI_ASSET=""
fi

if [ -n "$CLI_ASSET" ]; then
    CLI_URL="https://github.com/drakvai-sudo/se-pipeline-releases/releases/latest/download/$CLI_ASSET"
    CLI_BIN="$CLI_DIR/se-pipeline"
    if curl -fsSL "$CLI_URL" -o "$CLI_BIN"; then
        chmod +x "$CLI_BIN"
        echo "[OK] CLI installed to $CLI_BIN"
    else
        echo "[WARN] CLI download failed. Check your internet connection."
        echo "       Download manually from: https://github.com/drakvai-sudo/se-pipeline-releases/releases"
    fi
fi

# -- 7b. Ensure CLI_DIR is on PATH --
if [[ ":$PATH:" != *":$CLI_DIR:"* ]]; then
    SHELL_RC="$HOME/.bashrc"
    [ -n "${ZSH_VERSION:-}" ] && SHELL_RC="$HOME/.zshrc"
    echo "" >> "$SHELL_RC"
    echo "# se-pipeline CLI" >> "$SHELL_RC"
    echo "export PATH=\"$CLI_DIR:\$PATH\"" >> "$SHELL_RC"
    echo "[OK] $CLI_DIR added to PATH in $SHELL_RC"
    echo "     Run: source $SHELL_RC  (or open a new terminal)"
else
    echo "[OK] $CLI_DIR is already on PATH."
fi
echo ""

# ── 8. Done ───────────────────────────────────────
echo "============================================"
echo " Setup complete!"
echo "============================================"
echo ""
echo "se-pipeline is now available in every new terminal."
echo ""
echo "Open a new terminal and run:"
echo "  se-pipeline --help"
echo ""
echo "Useful commands:"
echo "  se-pipeline run --help              submit a task"
echo "  se-pipeline config set KEY value    set an API key"
echo "  docker compose ps                   check service status"
echo "  ./update.sh                         pull and apply updates"
echo ""
