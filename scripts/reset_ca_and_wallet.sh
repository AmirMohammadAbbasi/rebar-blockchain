#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "🛑 Stopping Fabric & CA containers..."
docker compose -f "$ROOT_DIR/docker-compose.yaml" \
               -f "$ROOT_DIR/docker-compose.test-ca.yml" down -v || true

# پاک کردن همه Volumeهای مربوط به CA
echo "🧹 Cleaning CA-related Docker volumes..."
CA_VOLUMES=$(docker volume ls -q | grep -E '(^ca\.|fabric-ca)' || true)
if [ -n "$CA_VOLUMES" ]; then
  docker volume rm $CA_VOLUMES || true
  echo "✅ Removed CA volumes: $CA_VOLUMES"
else
  echo "ℹ️ No CA-related volumes found."
fi

# پاک کردن کیف پول تست‌ها
echo "🗑 Removing integration test wallet..."
rm -rf "$ROOT_DIR/test/integration/wallet" || true

# ایجاد شبکه external اگر وجود ندارد
echo "🌐 Ensuring external network 'fabric_net' exists..."
docker network create fabric_net || true

# راه‌اندازی مجدد سرویس‌ها
echo "🚀 Starting Fabric & CA containers fresh..."
docker compose -f "$ROOT_DIR/docker-compose.yaml" \
               -f "$ROOT_DIR/docker-compose.test-ca.yml" up -d

echo "⏳ Waiting 5 seconds for containers to stabilize..."
sleep 5

# اجرای تست‌ها داخل کانتینر test-runner
echo "🧪 Running integration tests inside Docker..."
docker exec test-runner sh -c "
  npm install --prefix /workspace/test/integration &&
  npm test --prefix /workspace/test/integration
"

echo "✅ Environment reset and tests completed."
