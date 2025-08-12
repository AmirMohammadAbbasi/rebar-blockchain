#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOCKER_COMPOSE_FILE="$PROJECT_DIR/docker-compose.yaml"
CHANNEL_NAME="testchannel"
TEST_DOCKER_NETWORK="fabric_test_net"
ARTIFACTS_DIR="$PROJECT_DIR/artifacts"
CLI_ARTIFACTS_PATH="/etc/hyperledger/artifacts"

echo "🌐 Ensuring TEST Docker network exists..."
docker network ls | grep -q "$TEST_DOCKER_NETWORK" || docker network create "$TEST_DOCKER_NETWORK"

echo "🧹 Cleaning old TEST containers, volumes, and artifacts..."
docker compose -f "$DOCKER_COMPOSE_FILE" down -v --remove-orphans || true
rm -rf "$ARTIFACTS_DIR"

echo "🔨 Generating TEST artifacts..."
"$PROJECT_DIR/scripts/generate_artifacts.sh"

echo "🚀 Starting all Fabric TEST containers..."
docker compose -f "$DOCKER_COMPOSE_FILE" up -d

echo "⏳ Waiting for orderer & peers to be ready..."
sleep 10

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

echo "📄 Creating TEST channel: ${CHANNEL_NAME}"
exec_cli_test \
  ShamsMSP \
  "$CLI_ARTIFACTS_PATH/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp" \
  test-peer0.shams.example.com:7151 \
  peer channel create \
    -o test-orderer.example.com:7150 \
    -c "${CHANNEL_NAME}" \
    -f "${CLI_ARTIFACTS_PATH}/${CHANNEL_NAME}.tx" \
    --outputBlock "${CLI_ARTIFACTS_PATH}/${CHANNEL_NAME}.block"

echo "🔗 Joining TEST Shams peer..."
exec_cli_test \
  ShamsMSP \
  "$CLI_ARTIFACTS_PATH/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp" \
  test-peer0.shams.example.com:7151 \
  peer channel join -b "${CLI_ARTIFACTS_PATH}/${CHANNEL_NAME}.block"

echo "🔗 Joining TEST Rebar peer..."
exec_cli_test \
  RebarMSP \
  "$CLI_ARTIFACTS_PATH/crypto-config/peerOrganizations/rebar.example.com/users/Admin@rebar.example.com/msp" \
  test-peer0.rebar.example.com:9151 \
  peer channel join -b "${CLI_ARTIFACTS_PATH}/${CHANNEL_NAME}.block"

echo "📍 Updating TEST Shams anchor peers..."
exec_cli_test \
  ShamsMSP \
  "$CLI_ARTIFACTS_PATH/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp" \
  test-peer0.shams.example.com:7151 \
  peer channel update \
    -o test-orderer.example.com:7150 \
    -c "${CHANNEL_NAME}" \
    -f "${CLI_ARTIFACTS_PATH}/ShamsMSPanchors.tx"

echo "📍 Updating TEST Rebar anchor peers..."
exec_cli_test \
  RebarMSP \
  "$CLI_ARTIFACTS_PATH/crypto-config/peerOrganizations/rebar.example.com/users/Admin@rebar.example.com/msp" \
  test-peer0.rebar.example.com:9151 \
  peer channel update \
    -o test-orderer.example.com:7150 \
    -c "${CHANNEL_NAME}" \
    -f "${CLI_ARTIFACTS_PATH}/RebarMSPanchors.tx"

echo "✅ TEST Network started without TLS."
docker ps --format "table {{.Names}}	{{.Status}}"
