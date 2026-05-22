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
    if curl -sf http://localhost:8000/health >/dev/null 2>&1; then
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

echo "============================================"
echo " Update complete!"
echo "============================================"
echo ""
docker compose ps
echo ""
