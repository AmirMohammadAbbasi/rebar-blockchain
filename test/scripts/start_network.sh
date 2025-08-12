#!/bin/bash
set -e
source ./scripts/env.sh

CLI_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E '^test-cli$|cli$|cli[^/]*$' || true)
if [ -z "$CLI_CONTAINER" ]; then
  echo "❌ No CLI container found! Make sure 'docker compose up' started the tools container."
  exit 1
fi

# MSP paths
SHAMS_ADMIN_MSP=/etc/hyperledger/config/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp
REBAR_ADMIN_MSP=/etc/hyperledger/config/crypto-config/peerOrganizations/rebar.example.com/users/Admin@rebar.example.com/msp

echo "🧹 Cleaning old artifacts, containers & Docker volumes..."
docker compose -f docker-compose.yaml down -v --remove-orphans || true
docker volume rm $(docker volume ls -q | grep -E 'dev-peer|orderer|peer') 2>/dev/null || true
docker volume prune -f
rm -rf artifacts/*.block artifacts/*.tx config/crypto-config config/genesis.block config/*.block config/*.tx crypto-config

echo "🔨 Generating artifacts for channel: ${CHANNEL_NAME} ..."
export CHANNEL_NAME=$CHANNEL_NAME
./scripts/generate_artifacts.sh

echo "🚀 Starting all containers..."
docker compose -f docker-compose.yaml up -d

echo "⏳ Waiting for orderer & peers to be ready..."
sleep 10

echo "🔍 Validating configtx.yaml and profile RebarChannel..."
docker exec "$CLI_CONTAINER" sh -c '
  if [ ! -f /etc/hyperledger/config/configtx.yaml ]; then
    echo "❌ configtx.yaml not found at /etc/hyperledger/config"
    exit 1
  fi
  if ! grep -q "RebarChannel" /etc/hyperledger/config/configtx.yaml; then
    echo "❌ Profile RebarChannel not found in configtx.yaml"
    exit 1
  fi
'

echo "📄 STEP 1: Creating channel transaction (.tx) with Shams admin..."
docker exec \
    -e CORE_PEER_LOCALMSPID=ShamsMSP \
    -e CORE_PEER_ADDRESS=test-peer0.shams.example.com:7151 \
    -e CORE_PEER_MSPCONFIGPATH=$SHAMS_ADMIN_MSP \
    "$CLI_CONTAINER" \
    sh -c "FABRIC_CFG_PATH=/etc/hyperledger/config configtxgen \
      -configPath /etc/hyperledger/config \
      -profile RebarChannel \
      -outputCreateChannelTx /etc/hyperledger/config/${CHANNEL_NAME}.tx \
      -channelID ${CHANNEL_NAME}"

echo "✍️ STEP 2: Signing channel tx with Shams admin..."
docker exec \
    -e CORE_PEER_LOCALMSPID=ShamsMSP \
    -e CORE_PEER_ADDRESS=test-peer0.shams.example.com:7151 \
    -e CORE_PEER_MSPCONFIGPATH=$SHAMS_ADMIN_MSP \
    "$CLI_CONTAINER" \
    peer channel signconfigtx \
        -f /etc/hyperledger/config/${CHANNEL_NAME}.tx

echo "✍️ STEP 3: Signing channel tx with Rebar admin..."
docker exec \
    -e CORE_PEER_LOCALMSPID=RebarMSP \
    -e CORE_PEER_ADDRESS=test-peer0.rebar.example.com:9151 \
    -e CORE_PEER_MSPCONFIGPATH=$REBAR_ADMIN_MSP \
    "$CLI_CONTAINER" \
    peer channel signconfigtx \
        -f /etc/hyperledger/config/${CHANNEL_NAME}.tx

echo "🚀 STEP 4: Submitting channel creation..."
docker exec \
    -e CORE_PEER_LOCALMSPID=ShamsMSP \
    -e CORE_PEER_ADDRESS=test-peer0.shams.example.com:7151 \
    -e CORE_PEER_MSPCONFIGPATH=$SHAMS_ADMIN_MSP \
    "$CLI_CONTAINER" \
    peer channel create \
        -o test-orderer.example.com:7150 \
        -c ${CHANNEL_NAME} \
        -f /etc/hyperledger/config/${CHANNEL_NAME}.tx \
        --outputBlock /etc/hyperledger/config/${CHANNEL_NAME}.block \
        --tls=false

echo "🔗 Joining Shams peer..."
docker exec \
    -e CORE_PEER_LOCALMSPID=ShamsMSP \
    -e CORE_PEER_ADDRESS=test-peer0.shams.example.com:7151 \
    -e CORE_PEER_MSPCONFIGPATH=$SHAMS_ADMIN_MSP \
    "$CLI_CONTAINER" \
    peer channel join -b /etc/hyperledger/config/${CHANNEL_NAME}.block

echo "🔗 Joining Rebar peer..."
docker exec \
    -e CORE_PEER_LOCALMSPID=RebarMSP \
    -e CORE_PEER_ADDRESS=test-peer0.rebar.example.com:9151 \
    -e CORE_PEER_MSPCONFIGPATH=$REBAR_ADMIN_MSP \
    "$CLI_CONTAINER" \
    peer channel join -b /etc/hyperledger/config/${CHANNEL_NAME}.block

echo "📍 Updating Shams anchor..."
docker exec \
    -e CORE_PEER_LOCALMSPID=ShamsMSP \
    -e CORE_PEER_ADDRESS=test-peer0.shams.example.com:7151 \
    -e CORE_PEER_MSPCONFIGPATH=$SHAMS_ADMIN_MSP \
    "$CLI_CONTAINER" \
    peer channel update \
        -o test-orderer.example.com:7150 \
        -c ${CHANNEL_NAME} \
        -f /etc/hyperledger/config/ShamsMSPanchors.tx \
        --tls=false

echo "📍 Updating Rebar anchor..."
docker exec \
    -e CORE_PEER_LOCALMSPID=RebarMSP \
    -e CORE_PEER_ADDRESS=test-peer0.rebar.example.com:9151 \
    -e CORE_PEER_MSPCONFIGPATH=$REBAR_ADMIN_MSP \
    "$CLI_CONTAINER" \
    peer channel update \
        -o test-orderer.example.com:7150 \
        -c ${CHANNEL_NAME} \
        -f /etc/hyperledger/config/RebarMSPanchors.tx \
        --tls=false

echo "✅ Test network setup complete with enforced 2-admin signature."
docker ps --format "table {{.Names}}	{{.Status}}"
