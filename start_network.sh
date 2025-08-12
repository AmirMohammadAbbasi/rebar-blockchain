#!/bin/bash
set -e
source ./scripts/env.sh

echo "🧹 Cleaning old artifacts & containers..."
docker compose down -v --remove-orphans
rm -rf config/crypto-config config/*.block config/*.tx

echo "🔨 Generating artifacts..."
./scripts/generate_artifacts.sh

echo "🚀 Starting all containers..."
docker compose up -d

echo "⏳ Waiting for orderer & peers to be ready..."
sleep 5
# میتونی اینجا healthcheck لوپ بذاری ولی یه تاخیر کوتاه معمولاً کافیه
# اگر خواستی میشه upgrade کرد که حتما تا healthy شدن وایسه

echo "📄 Creating channel: ${CHANNEL_NAME}"
docker exec cli peer channel create \
    -o orderer.example.com:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    -c ${CHANNEL_NAME} \
    -f ./config/${CHANNEL_NAME}.tx \
    --tls \
    --cafile /etc/hyperledger/fabric/tlsca/tlsca.example.com-cert.pem

echo "🔗 Joining peer0.shams.example.com"
docker exec -e CORE_PEER_LOCALMSPID=ShamsMSP \
            -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/msp/users/Admin@shams.example.com/msp \
            -e CORE_PEER_ADDRESS=peer0.shams.example.com:7051 \
    cli peer channel join -b ${CHANNEL_NAME}.block

echo "🔗 Joining peer0.rebar.example.com"
docker exec -e CORE_PEER_LOCALMSPID=RebarMSP \
            -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/msp/users/Admin@rebar.example.com/msp \
            -e CORE_PEER_ADDRESS=peer0.rebar.example.com:9051 \
    cli peer channel join -b ${CHANNEL_NAME}.block

echo "📍 Updating Anchor Peer for ShamsMSP"
docker exec -e CORE_PEER_LOCALMSPID=ShamsMSP \
            -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/msp/users/Admin@shams.example.com/msp \
            -e CORE_PEER_ADDRESS=peer0.shams.example.com:7051 \
    cli peer channel update \
        -o orderer.example.com:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        -c ${CHANNEL_NAME} \
        -f ./config/ShamsMSPanchors.tx \
        --tls \
        --cafile /etc/hyperledger/fabric/tlsca/tlsca.example.com-cert.pem

echo "📍 Updating Anchor Peer for RebarMSP"
docker exec -e CORE_PEER_LOCALMSPID=RebarMSP \
            -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/msp/users/Admin@rebar.example.com/msp \
            -e CORE_PEER_ADDRESS=peer0.rebar.example.com:9051 \
    cli peer channel update \
        -o orderer.example.com:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        -c ${CHANNEL_NAME} \
        -f ./config/RebarMSPanchors.tx \
        --tls \
        --cafile /etc/hyperledger/fabric/tlsca/tlsca.example.com-cert.pem

echo "✅ Network ready! All peers joined & anchors updated."
