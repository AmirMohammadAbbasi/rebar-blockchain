#!/bin/bash
set -e
source ./scripts/env.sh

echo "🧹 Cleaning old artifacts & containers..."
docker compose -f docker-compose.yaml down -v --remove-orphans || true
rm -rf config/crypto-config config/*.block config/*.tx

echo "🔨 Generating artifacts..."
./scripts/generate_artifacts.sh

echo "🚀 Starting all containers..."
docker compose -f docker-compose.yaml up -d

echo "⏳ Waiting for orderer & peers to be ready..."
sleep 10

echo "📄 Creating channel: ${CHANNEL_NAME}"
docker exec cli peer channel create \
  -o orderer.example.com:7050 \
  -c ${CHANNEL_NAME} \
  -f /etc/hyperledger/config/${CHANNEL_NAME}.tx

echo "🔗 Joining shams peer..."
docker exec cli peer channel join \
  -b ${CHANNEL_NAME}.block

echo "🔗 Joining rebar peer..."
docker exec -e CORE_PEER_ADDRESS=peer0.rebar.example.com:9051 \
           -e CORE_PEER_LOCALMSPID=RebarMSP \
           -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/peer/msp \
           cli peer channel join -b ${CHANNEL_NAME}.block

echo "📍 Updating Shams anchor peers..."
docker exec cli peer channel update \
  -o orderer.example.com:7050 \
  -c ${CHANNEL_NAME} \
  -f /etc/hyperledger/config/ShamsMSPanchors.tx

echo "📍 Updating Rebar anchor peers..."
docker exec -e CORE_PEER_ADDRESS=peer0.rebar.example.com:9051 \
           -e CORE_PEER_LOCALMSPID= \
           -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/peer/msp \
           cli peer channel update \
              -o orderer.example.com:7050 \
              -c ${CHANNEL_NAME} \
              -f /etc/hyperledger/config/RebarMSPanchors.tx

echo "✅ Network setup complete without TLS."
docker ps --format "table {{.Names}}	{{.Status}}"
