#!/bin/bash
set -e
source ./scripts/env.sh

CHANNEL_NAME="testchannel"

# مسیرهای درست MSP داخل کانتینر cli
SHAMS_ADMIN_MSP=/etc/hyperledger/config/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp
REBAR_ADMIN_MSP=/etc/hyperledger/config/crypto-config/peerOrganizations/rebar.example.com/users/Admin@rebar.example.com/msp

echo "🧹 Cleaning old artifacts & containers..."
docker compose -f docker-compose.yaml down -v --remove-orphans || true
rm -rf artifacts/*.block artifacts/*.tx crypto-config

echo "🔨 Generating artifacts..."
./scripts/generate_artifacts.sh

echo "🚀 Starting all containers..."
docker compose -f docker-compose.yaml up -d

echo "⏳ Waiting for orderer & peers to be ready..."
sleep 10

# ========= STEP 1: Create channel configuration transaction with Shams admin =========
echo "📄 STEP 1: Creating channel transaction (.tx) with Shams admin..."
docker exec \
    -e CORE_PEER_LOCALMSPID=ShamsMSP \
    -e CORE_PEER_ADDRESS=peer0.shams.example.com:7051 \
    -e CORE_PEER_MSPCONFIGPATH=$SHAMS_ADMIN_MSP \
    cli \
    sh -c "FABRIC_CFG_PATH=/etc/hyperledger/config configtxgen -profile RebarChannel -outputCreateChannelTx /etc/hyperledger/config/${CHANNEL_NAME}.tx -channelID ${CHANNEL_NAME}"

# ========= STEP 2: Sign channel tx with Shams admin =========
echo "✍️ STEP 2: Signing channel tx with Shams admin..."
docker exec \
    -e CORE_PEER_LOCALMSPID=ShamsMSP \
    -e CORE_PEER_ADDRESS=peer0.shams.example.com:7051 \
    -e CORE_PEER_MSPCONFIGPATH=$SHAMS_ADMIN_MSP \
    cli \
    peer channel signconfigtx \
        -f /etc/hyperledger/config/${CHANNEL_NAME}.tx

# ========= STEP 3: Sign channel tx with Rebar admin =========
echo "✍️ STEP 3: Signing channel tx with Rebar admin..."
docker exec \
    -e CORE_PEER_LOCALMSPID=RebarMSP \
    -e CORE_PEER_ADDRESS=peer0.rebar.example.com:9051 \
    -e CORE_PEER_MSPCONFIGPATH=$REBAR_ADMIN_MSP \
    cli \
    peer channel signconfigtx \
        -f /etc/hyperledger/config/${CHANNEL_NAME}.tx

# ========= STEP 4: Submit multi-signed channel creation =========
echo "🚀 STEP 4: Submitting channel creation..."
docker exec \
    -e CORE_PEER_LOCALMSPID=ShamsMSP \
    -e CORE_PEER_ADDRESS=peer0.shams.example.com:7051 \
    -e CORE_PEER_MSPCONFIGPATH=$SHAMS_ADMIN_MSP \
    cli \
    peer channel create \
        -o orderer.example.com:7050 \
        -c ${CHANNEL_NAME} \
        -f /etc/hyperledger/config/${CHANNEL_NAME}.tx \
        --outputBlock /etc/hyperledger/config/${CHANNEL_NAME}.block \
        --tls=false

# ========= STEP 5: Join both peers =========
echo "🔗 Joining Shams peer..."
docker exec \
    -e CORE_PEER_LOCALMSPID=ShamsMSP \
    -e CORE_PEER_ADDRESS=peer0.shams.example.com:7051 \
    -e CORE_PEER_MSPCONFIGPATH=$SHAMS_ADMIN_MSP \
    cli \
    peer channel join -b /etc/hyperledger/config/${CHANNEL_NAME}.block

echo "🔗 Joining Rebar peer..."
docker exec \
    -e CORE_PEER_LOCALMSPID=RebarMSP \
    -e CORE_PEER_ADDRESS=peer0.rebar.example.com:9051 \
    -e CORE_PEER_MSPCONFIGPATH=$REBAR_ADMIN_MSP \
    cli \
    peer channel join -b /etc/hyperledger/config/${CHANNEL_NAME}.block

# ========= STEP 6: Update anchor peers =========
echo "📍 Updating Shams anchor..."
docker exec \
    -e CORE_PEER_LOCALMSPID=ShamsMSP \
    -e CORE_PEER_ADDRESS=peer0.shams.example.com:7051 \
    -e CORE_PEER_MSPCONFIGPATH=$SHAMS_ADMIN_MSP \
    cli \
    peer channel update \
        -o orderer.example.com:7050 \
        -c ${CHANNEL_NAME} \
        -f /etc/hyperledger/config/ShamsMSPanchors.tx \
        --tls=false

echo "📍 Updating Rebar anchor..."
docker exec \
    -e CORE_PEER_LOCALMSPID=RebarMSP \
    -e CORE_PEER_ADDRESS=peer0.rebar.example.com:9051 \
    -e CORE_PEER_MSPCONFIGPATH=$REBAR_ADMIN_MSP \
    cli \
    peer channel update \
        -o orderer.example.com:7050 \
        -c ${CHANNEL_NAME} \
        -f /etc/hyperledger/config/RebarMSPanchors.tx \
        --tls=false

echo "✅ Test network setup complete with enforced 2-admin signature."
docker ps --format "table {{.Names}}	{{.Status}}"
