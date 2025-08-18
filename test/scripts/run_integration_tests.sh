#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/env.sh"

echo "Current directory: ${ROOT_DIR}"

echo "🧪 Running integration tests inside test-runner container..."

# اجرای تست‌ها داخل کانتینر test-runner
docker exec test-runner bash -c "
    cd /app &&
    echo '📦 Installing test dependencies...' &&
    npm install --no-audit --no-fund &&
    echo '🧪 Running integration tests...' &&
    npm test
"

echo "✅ Integration tests completed."
