#!/bin/bash
set -e

# مسیر پروژه تست
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOCKER_COMPOSE_FILE="$PROJECT_DIR/docker-compose.yaml"

# بارگذاری متغیرها
CHANNEL_NAME="testchannel"
TEST_DOCKER_NETWORK="fabric_test_net"

echo "🌐 Ensuring TEST Docker network exists..."
docker network ls | grep -q "$TEST_DOCKER_NETWORK" || docker network create "$TEST_DOCKER_NETWORK"

echo "🧹 Cleaning old TEST containers, volumes, and artifacts..."
docker compose -f "$DOCKER_COMPOSE_FILE" down -v --remove-orphans || true
rm -rf "$PROJECT_DIR/config/artifacts"

echo "🔨 Generating TEST artifacts..."
"$PROJECT_DIR/scripts/generate_artifacts.sh"

echo "🚀 Starting all Fabric TEST containers..."
docker compose -f "$DOCKER_COMPOSE_FILE" up -d

echo "⏳ Waiting for TEST orderer & peers to be ready..."
sleep 10

# Helper برای اجرای دستورات peer داخل CLI تست
exec_cli_test() {
  local MSP_ID="$1"
  local MSP_PATH="$2"
  local PEER_ADDRESS="$3"
  shift 3
  docker exec \
    -e CORE_PEER_LOCALMSPID="$MSP_ID" \
    -e CORE_PEER_MSPCONFIGPATH="$MSP_PATH" \
    -e CORE_PEER_ADDRESS="$PEER_ADDRESS" \
    -e CORE_PEER_TLS_ENABLED=false \
    test-cli "$@"
}

# ==== ساخت کانال (ShamsMSP Admin) ====
echo "📄 Creating TEST channel: ${CHANNEL_NAME}"
exec_cli_test \
  ShamsMSP \
  /etc/hyperledger/config/artifacts/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp \
  test-peer0.shams.example.com:7151 \
  peer channel create \
    -o test-orderer.example.com:7150 \
    -c "${CHANNEL_NAME}" \
    -f "/etc/hyperledger/config/artifacts/${CHANNEL_NAME}.tx" \
    --outputBlock "/etc/hyperledger/config/artifacts/${CHANNEL_NAME}.block"

# ==== Join Shams peer ====
echo "🔗 Joining TEST Shams peer..."
exec_cli_test \
  ShamsMSP \
  /etc/hyperledger/config/artifacts/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp \
  test-peer0.shams.example.com:7151 \
  peer channel join -b "/etc/hyperledger/config/artifacts/${CHANNEL_NAME}.block"

# ==== Join Rebar peer ====
echo "🔗 Joining TEST Rebar peer..."
exec_cli_test \
  RebarMSP \
  /etc/hyperledger/config/artifacts/crypto-config/peerOrganizations/rebar.example.com/users/Admin@rebar.example.com/msp \
  test-peer0.rebar.example.com:9151 \
  peer channel join -b "/etc/hyperledger/config/artifacts/${CHANNEL_NAME}.block"

# ==== Update Shams anchor peers ====
echo "📍 Updating TEST Shams anchor peers..."
exec_cli_test \
  ShamsMSP \
  /etc/hyperledger/config/artifacts/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp \
  test-peer0.shams.example.com:7151 \
  peer channel update \
    -o test-orderer.example.com:7150 \
    -c "${CHANNEL_NAME}" \
    -f "/etc/hyperledger/config/artifacts/ShamsMSPanchors.tx"

# ==== Update Rebar anchor peers ====
echo "📍 Updating TEST Rebar anchor peers..."
exec_cli_test \
  RebarMSP \
  /etc/hyperledger/config/artifacts/crypto-config/peerOrganizations/rebar.example.com/users/Admin@rebar.example.com/msp \
  test-peer0.rebar.example.com:9151 \
  peer channel update \
    -o test-orderer.example.com:7150 \
    -c "${CHANNEL_NAME}" \
    -f "/etc/hyperledger/config/artifacts/RebarMSPanchors.tx"

echo "✅ TEST Network setup complete without TLS."
docker ps --format "table {{.Names}}	{{.Status}}"
