#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/env.sh"

echo ${ROOT_DIR}




echo "📦 Installing test dependencies inside test-runner..."
# اگر ابزارهای سیستمی لازم داری (docker, netcat, ping)، می‌تونی اینجا نصب کنی
apt-get update && apt-get install -y docker.io netcat iputils-ping

cd "$ROOT_DIR"

# نصب پکیج‌های Node.js تست‌ها
npm install --no-audit --no-fund

echo "🧪 Running integration tests..."
npm test

echo "✅ Integration tests completed."
