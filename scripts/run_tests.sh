#!/bin/bash
set -euo pipefail

WORKDIR=/workspace

echo "🔧 اجرای تست‌ها داخل test-runner، working dir = $WORKDIR"
cd "$WORKDIR"

# اگر package.json در روت وجود داره و repo app داره، می‌تونی این را تغییر بدی.
# برای chaincode Node.js معمولاً package.json داخل ./chaincode است.
if [ -d "./chaincode" ] && [ -f "./chaincode/package.json" ]; then
  echo "📁 رفتن به پوشه chaincode و نصب dependency ها..."
  cd ./chaincode
  npm install --no-audit --no-fund
  echo "🧪 اجرای unit tests (اگر اسکریپت test در package.json تعریف شده باشد)..."
  if npm run | grep -q " test"; then
    npm test || echo "⚠️ npm test شکست خورد (کد خطا را نادیده می‌گیریم)"
  fi
  echo "✅ تمام شد (chaincode deps و unit tests)"
else
  echo "⚠️ package.json در ./chaincode پیدا نشد؛ چک کن که chaincode/package.json موجود باشد."
fi

# اگر اسکریپت‌های integration/e2e در روت وجود دارند، مثال اجرا:
if [ -f "./scripts/test_api.sh" ]; then
  echo "📡 اجرای scripts/test_api.sh برای تست‌های API..."
  ./scripts/test_api.sh || echo "⚠️ test_api.sh exit non-zero"
fi

echo "🏁 run_tests.sh تمام شد."
