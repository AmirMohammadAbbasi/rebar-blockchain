#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "🛑 Stopping Fabric main & test containers..."
docker compose -f "$ROOT_DIR/docker-compose.yaml" down -v || true
docker compose -f "$ROOT_DIR/docker-compose.test.yaml" down -v || true

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

# راه‌اندازی مجدد سرویس‌های TLS اصلی
echo "🚀 Starting main Fabric TLS network..."
docker compose -f "$ROOT_DIR/docker-compose.yaml" up -d

echo "⏳ Waiting 5 seconds for network to stabilize..."
sleep 5

# اجرای تست‌ها از طریق محیط تست Non-TLS
echo "🧪 Running integration tests..."
docker compose -f "$ROOT_DIR/docker-compose.test.yaml" up --abort-on-container-exit

# پاکسازی محیط تست
docker compose -f "$ROOT_DIR/docker-compose.test.yaml" down -v

echo "✅ Environment reset and tests completed."
