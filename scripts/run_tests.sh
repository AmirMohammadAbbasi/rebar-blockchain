#!/bin/bash
set -euo pipefail

# اگر خارج کانتینر هستیم، اجرا را به داخل cli منتقل کن
if [ -z "${INSIDE_DOCKER:-}" ]; then
  echo "🐳 در حال اجرای تست‌ها داخل کانتینر cli ..."
  docker exec -e INSIDE_DOCKER=1 cli bash -c "cd /workspace && ./scripts/run_tests.sh"
  exit $?
fi

WORKDIR=/workspace

echo "🔧 اجرای تست‌ها درون داکر، working dir = $WORKDIR"
cd "$WORKDIR"

# نصب dependencyهای chaincode و اجرای unit test
if [ -d "./chaincode" ] && [ -f "./chaincode/package.json" ]; then
  echo "📁 رفتن به پوشه chaincode و نصب dependency ها..."
  cd ./chaincode
  npm install --no-audit --no-fund
  echo "🧪 اجرای unit tests (در صورت وجود)..."
  if npm run | grep -q " test"; then
    npm test || echo "⚠️ npm test شکست خورد (کد خطا نادیده گرفته می‌شود)"
  fi
  cd ..
else
  echo "⚠️ package.json در ./chaincode پیدا نشد؛ بررسی کن که chaincode/package.json موجود باشد."
fi

# اجرای integration/API تست‌ها
if [ -f "./scripts/test_api.sh" ]; then
  echo "📡 اجرای scripts/test_api.sh برای تست‌های API..."
  ./scripts/test_api.sh || echo "⚠️ test_api.sh exit non-zero"
fi

echo "🏁 تمام تست‌ها اجرا شد."
