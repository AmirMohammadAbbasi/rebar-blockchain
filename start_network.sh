#!/bin/bash
set -e

# مسیر پروژه
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_COMPOSE_FILE="$PROJECT_DIR/docker-compose.yaml"

# بارگذاری متغیر‌ها
source "$PROJECT_DIR/scripts/env.sh"
: "${CHANNEL_NAME:?CHANNEL_NAME not set in env.sh}"

echo "🌐 Ensuring Docker network exists..."
docker network ls | grep -q fabric_net || docker network create fabric_net

echo "🧹 Cleaning old containers, volumes, and artifacts..."
docker compose -f "$DOCKER_COMPOSE_FILE" down -v --remove-orphans || true
rm -rf "$PROJECT_DIR/config/crypto-config" \
       "$PROJECT_DIR/config"/*.block \
       "$PROJECT_DIR/config"/*.tx

echo "🔨 Generating artifacts..."
"$PROJECT_DIR/scripts/generate_artifacts.sh"

echo "🚀 Starting all Fabric containers..."
docker compose -f "$DOCKER_COMPOSE_FILE" up -d

echo "⏳ Waiting for orderer & peers healthchecks..."
sleep 10

# Helper to run peer commands inside CLI container
exec_cli() {
  local MSP_ID="$1"
  local MSP_PATH="$2"
  local PEER_ADDRESS="$3"
  shift 3
  docker exec \
    -e CORE_PEER_LOCALMSPID="$MSP_ID" \
    -e CORE_PEER_MSPCONFIGPATH="$MSP_PATH" \
    -e CORE_PEER_ADDRESS="$PEER_ADDRESS" \
    -e CORE_PEER_TLS_ENABLED=false \
    cli "$@"
}

# ==== Channel creation (ShamsMSP Admin) ====
echo "📄 Creating channel: ${CHANNEL_NAME}"
exec_cli \
  ShamsMSP \
  /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp \
  peer0.shams.example.com:7051 \
  peer channel create \
    -o orderer.example.com:7050 \
    -c "${CHANNEL_NAME}" \
    -f "/etc/hyperledger/config/${CHANNEL_NAME}.tx" \
    --outputBlock "/etc/hyperledger/config/${CHANNEL_NAME}.block"

# ==== Join Shams peer ====
echo "🔗 Joining Shams peer..."
exec_cli \
  ShamsMSP \
  /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp \
  peer0.shams.example.com:7051 \
  peer channel join -b "/etc/hyperledger/config/${CHANNEL_NAME}.block"

# ==== Join Rebar peer ====
echo "🔗 Joining Rebar peer..."
exec_cli \
  RebarMSP \
  /etc/hyperledger/crypto-config/peerOrganizations/rebar.example.com/users/Admin@rebar.example.com/msp \
  peer0.rebar.example.com:9051 \
  peer channel join -b "/etc/hyperledger/config/${CHANNEL_NAME}.block"

# ==== Update Shams anchor peers ====
echo "📍 Updating Shams anchor peers..."
exec_cli \
  ShamsMSP \
  /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp \
  peer0.shams.example.com:7051 \
  peer channel update \
    -o orderer.example.com:7050 \
    -c "${CHANNEL_NAME}" \
    -f "/etc/hyperledger/config/ShamsMSPanchors.tx"

# ==== Update Rebar anchor peers ====
echo "📍 Updating Rebar anchor peers..."
exec_cli \
  RebarMSP \
  /etc/hyperledger/crypto-config/peerOrganizations/rebar.example.com/users/Admin@rebar.example.com/msp \
  peer0.rebar.example.com:9051 \
  peer channel update \
    -o orderer.example.com:7050 \
    -c "${CHANNEL_NAME}" \
    -f "/etc/hyperledger/config/RebarMSPanchors.tx"

echo "✅ Network setup complete without TLS."
docker ps --format "table {{.Names}}	{{.Status}}"
