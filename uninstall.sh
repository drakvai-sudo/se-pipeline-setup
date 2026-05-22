#!/usr/bin/env bash
set -e

cd "$(cd "$(dirname "$0")" && pwd)"

echo "============================================"
echo " se-pipeline -- Uninstall"
echo "============================================"
echo ""
echo "This will stop all services and remove all data volumes."
echo "Your .env configuration file will NOT be deleted."
echo ""
read -r -p "Are you sure? Type YES to continue: " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
    echo "Cancelled."
    exit 0
fi
echo ""

# Stop and remove containers + volumes
if docker info &>/dev/null; then
    echo "Stopping and removing services..."
    docker compose down -v
    echo "[OK] Services stopped and data volumes removed."
else
    echo "[WARN] Docker is not running -- skipping container removal."
fi
echo ""

# Remove CLI wrapper
CLI_WRAPPER="$HOME/.local/bin/se-pipeline"
if [ -f "$CLI_WRAPPER" ]; then
    rm -f "$CLI_WRAPPER"
    echo "[OK] CLI wrapper removed from $HOME/.local/bin"
else
    echo "[OK] CLI wrapper not found -- nothing to remove."
fi
echo ""

echo "============================================"
echo " Uninstall complete."
echo "============================================"
echo ""
echo "Your .env file has been kept at:"
echo "  $(pwd)/.env"
echo "Delete it manually if you no longer need your configuration."
echo ""
