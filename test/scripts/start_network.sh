#!/bin/bash
set -e
source ./scripts/env.sh

CHANNEL_NAME="testchannel"

echo "🧹 Cleaning old artifacts & containers..."
docker compose -f docker-compose.yaml down -v --remove-orphans || true
rm -rf artifacts/*.block artifacts/*.tx crypto-config

echo "🔨 Generating artifacts..."
./scripts/generate_artifacts.sh

echo "🚀 Starting all containers..."
docker compose -f docker-compose.yaml up -d

echo "⏳ Waiting for orderer & peers to be ready..."
sleep 10

# ========= STEP 1: Create channel tx with Shams admin =========
echo "📄 STEP 1: Generating channel block with Shams admin..."
docker exec \
    -e CORE_PEER_LOCALMSPID=ShamsMSP \
    -e CORE_PEER_ADDRESS=peer0.shams.example.com:7051 \
    -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/users/Admin@shams.example.com/msp \
    cli \
    peer channel create \
        -o orderer.example.com:7050 \
        -c ${CHANNEL_NAME} \
        -f /etc/hyperledger/config/${CHANNEL_NAME}.tx \
        --outputBlock /etc/hyperledger/config/${CHANNEL_NAME}.block \
        --tls=false \
        --clientauth=false

# ========= STEP 2: Sign channel tx with Rebar admin =========
echo "✍️ STEP 2: Signing channel configtx with Rebar admin..."
docker exec \
    -e CORE_PEER_LOCALMSPID=RebarMSP \
    -e CORE_PEER_ADDRESS=peer0.rebar.example.com:9051 \
    -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/users/Admin@rebar.example.com/msp \
    cli \
    peer channel signconfigtx \
        -f /etc/hyperledger/config/${CHANNEL_NAME}.tx

# ========= STEP 3: Submit channel creation =========
# یکی از Adminها (مثلاً Shams) تراکنش امضا شده رو submit می‌کنه
echo "🚀 STEP 3: Submitting multi-signed channel creation..."
docker exec \
    -e CORE_PEER_LOCALMSPID=ShamsMSP \
    -e CORE_PEER_ADDRESS=peer0.shams.example.com:7051 \
    -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/users/Admin@shams.example.com/msp \
    cli \
    peer channel create \
        -o orderer.example.com:7050 \
        -c ${CHANNEL_NAME} \
        -f /etc/hyperledger/config/${CHANNEL_NAME}.tx \
        --outputBlock /etc/hyperledger/config/${CHANNEL_NAME}.block \
        --tls=false \
        --clientauth=false

# ========= STEP 4: Join both peers =========
echo "🔗 Joining Shams peer..."
docker exec \
    -e CORE_PEER_LOCALMSPID=ShamsMSP \
    -e CORE_PEER_ADDRESS=peer0.shams.example.com:7051 \
    -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/users/Admin@shams.example.com/msp \
    cli \
    peer channel join -b /etc/hyperledger/config/${CHANNEL_NAME}.block

echo "🔗 Joining Rebar peer..."
docker exec \
    -e CORE_PEER_LOCALMSPID=RebarMSP \
    -e CORE_PEER_ADDRESS=peer0.rebar.example.com:9051 \
    -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/users/Admin@rebar.example.com/msp \
    cli \
    peer channel join -b /etc/hyperledger/config/${CHANNEL_NAME}.block

# ========= STEP 5: Update anchor peers =========
echo "📍 Updating Shams anchor..."
docker exec \
    -e CORE_PEER_LOCALMSPID=ShamsMSP \
    -e CORE_PEER_ADDRESS=peer0.shams.example.com:7051 \
    -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/users/Admin@shams.example.com/msp \
    cli \
    peer channel update \
        -o orderer.example.com:7050 \
        -c ${CHANNEL_NAME} \
        -f /etc/hyperledger/config/ShamsMSPanchors.tx \
        --tls=false \
        --clientauth=false

echo "📍 Updating Rebar anchor..."
docker exec \
    -e CORE_PEER_LOCALMSPID=RebarMSP \
    -e CORE_PEER_ADDRESS=peer0.rebar.example.com:9051 \
    -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/users/Admin@rebar.example.com/msp \
    cli \
    peer channel update \
        -o orderer.example.com:7050 \
        -c ${CHANNEL_NAME} \
        -f /etc/hyperledger/config/RebarMSPanchors.tx \
        --tls=false \
        --clientauth=false

echo "✅ Test network setup complete with multi-signature policy."
docker ps --format "table {{.Names}}	{{.Status}}"
