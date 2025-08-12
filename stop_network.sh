#!/bin/bash
set -e

# ============================
# stop_network.sh
# پاک کردن ایمن کانتینرها، ولوم‌ها و شبکه‌ی Docker مربوط به پروژه
# اجرا از روت پروژه (مثلاً rebar-blockchain/)
# ============================

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)
COMPOSE_PATH="$PROJECT_DIR/docker-compose.yaml"
# نام شبکه‌ای که docker compose ایجاد می‌کند (معمولاً docker_default)
# اگر می‌خوای دقیق‌تر باشه می‌تونی اسم شبکه واقعی رو بذاری
PROJECT_NETWORK="docker_default"

echo "🛑 Stopping and removing containers defined in $COMPOSE_PATH (if any)..."

# اگر docker compose فایل موجود باشه از اون برای شناسایی سرویس‌ها استفاده کن
if [ -f "$COMPOSE_PATH" ]; then
  # Use docker compose to stop and remove containers/services
  docker compose -f "$COMPOSE_PATH" down --remove-orphans || true
else
  echo "⚠️  $COMPOSE_PATH not found — trying graceful manual cleanup..."
fi

# نام‌های کانتینر شناخته شده‌ی پروژه (مطابق docker-compose معمول شبکه Fabric دو-org)
CANONICAL_CONTAINERS=(
  "peer0.shams.example.com"
  "peer0.rebar.example.com"
  "orderer.example.com"
  "cli"                     # در صورت وجود service cli
  "ca.shams.example.com"
  "ca.rebar.example.com"
  "couchdb.shams"
  "couchdb.rebar"
)

# حذف کانتینرهای شناخته شده در صورت وجود (force remove)
for c in "${CANONICAL_CONTAINERS[@]}"; do
  if docker ps -a --format '{{.Names}}' | grep -wq "$c"; then
    echo "Removing container: $c"
    docker rm -f "$c" || true
  fi
done

# حذف کانتینرهای dangling/باقی‌مانده با الگوی نامی شبکه (مثلاً .example.com)
echo "Removing leftover containers with '.example.com' in name..."
docker ps -a --format '{{.Names}}' | grep '\.example\.com' -E || true
docker ps -a --format '{{.Names}}' | grep '\.example\.com' -E | xargs -r docker rm -f || true

# حذف ولوم‌های ساخته‌شده مخصوص پروژه (به صورت ایمن)
echo "Pruning project volumes created by docker compose (confirming names)..."
docker volume ls --format '{{.Name}}' | grep -E 'rebar|shams|fabric|peer' -E || true
docker volume ls --format '{{.Name}}' | grep -E 'rebar|shams|fabric|peer' -E | xargs -r docker volume rm || true

# حذف شبکه‌ی ساخته‌شده (اگر وجود داشت)
if docker network ls --format '{{.Name}}' | grep -wq "$PROJECT_NETWORK"; then
  echo "Removing network: $PROJECT_NETWORK"
  docker network rm "$PROJECT_NETWORK" || true
fi

# حالت کلی: نمایش وضعیت فعلی برای رفع اشکال
echo "Current running containers:"
docker ps -a --format "table {{.Names}}	{{.Status}}	{{.Image}}"

echo "Current volumes:"
docker volume ls

echo "✅ Cleanup finished."
