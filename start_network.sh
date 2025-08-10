#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "🚀 Generating artifacts..."
./scripts/generate_artifacts.sh

echo "🟢 Starting docker network..."
docker-compose -f docker/docker-compose.yaml up -d

echo "📦 Installing and approving chaincode..."
./scripts/install_chaincode.sh

echo "🧪 Running API test..."
./scripts/test_api.sh
