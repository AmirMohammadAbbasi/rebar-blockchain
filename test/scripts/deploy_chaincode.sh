#!/bin/bash
set -e

TEST_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$TEST_DIR/scripts"
source "$SCRIPTS_DIR/env.sh"

echo "📦 Deploying chaincode..."

# تابع کمکی برای اجرای دستورات peer
exec_peer() {
    local MSP_ID="$1"
    local MSP_PATH="$2"
    local PEER_ADDRESS="$3"
    shift 3
    
    docker exec \
        -e CORE_PEER_TLS_ENABLED=false \
        -e CORE_PEER_LOCALMSPID="$MSP_ID" \
        -e CORE_PEER_MSPCONFIGPATH="$MSP_PATH" \
        -e CORE_PEER_ADDRESS="$PEER_ADDRESS" \
        test-cli "$@"
}

# بسته‌بندی chaincode
echo "📦 Packaging chaincode..."
exec_peer ShamsMSP \
    /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp \
    test-peer0.shams.example.com:7151 \
    peer lifecycle chaincode package shamscontract.tar.gz \
        --path /opt/gopath/src/github.com/chaincode \
        --lang node \
        --label shamscontract_1.0

# نصب chaincode روی peer0.shams
echo "📦 Installing chaincode on Shams peer..."
exec_peer ShamsMSP \
    /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp \
    test-peer0.shams.example.com:7151 \
    peer lifecycle chaincode install shamscontract.tar.gz

# نصب chaincode روی peer0.rebar
echo "📦 Installing chaincode on Rebar peer..."
exec_peer RebarMSP \
    /etc/hyperledger/crypto-config/peerOrganizations/rebar.example.com/users/Admin@rebar.example.com/msp \
    test-peer0.rebar.example.com:9151 \
    peer lifecycle chaincode install shamscontract.tar.gz

# دریافت package ID (بدون jq)
echo "🔍 Getting package ID..."
PACKAGE_ID=$(exec_peer ShamsMSP \
    /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp \
    test-peer0.shams.example.com:7151 \
    peer lifecycle chaincode queryinstalled | grep -o 'shamscontract_1.0:[a-f0-9]*' | head -1)

echo "Package ID: $PACKAGE_ID"

if [ -z "$PACKAGE_ID" ]; then
    echo "❌ Failed to get package ID"
    exit 1
fi

# تایید chaincode توسط Shams
echo "✅ Approving chaincode for Shams..."
exec_peer ShamsMSP \
    /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp \
    test-peer0.shams.example.com:7151 \
    peer lifecycle chaincode approveformyorg \
        --channelID "$CHANNEL_NAME" \
        --name shamscontract \
        --version 1.0 \
        --package-id "$PACKAGE_ID" \
        --sequence 1 \
        --orderer test-orderer.example.com:7150

# تایید chaincode توسط Rebar
echo "✅ Approving chaincode for Rebar..."
exec_peer RebarMSP \
    /etc/hyperledger/crypto-config/peerOrganizations/rebar.example.com/users/Admin@rebar.example.com/msp \
    test-peer0.rebar.example.com:9151 \
    peer lifecycle chaincode approveformyorg \
        --channelID "$CHANNEL_NAME" \
        --name shamscontract \
        --version 1.0 \
        --package-id "$PACKAGE_ID" \
        --sequence 1 \
        --orderer test-orderer.example.com:7150

# بررسی آمادگی commit
echo "🔍 Checking commit readiness..."
exec_peer ShamsMSP \
    /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp \
    test-peer0.shams.example.com:7151 \
    peer lifecycle chaincode checkcommitreadiness \
        --channelID "$CHANNEL_NAME" \
        --name shamscontract \
        --version 1.0 \
        --sequence 1 \
        --orderer test-orderer.example.com:7150

# commit chaincode
echo "🚀 Committing chaincode..."
exec_peer ShamsMSP \
    /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp \
    test-peer0.shams.example.com:7151 \
    peer lifecycle chaincode commit \
        --channelID "$CHANNEL_NAME" \
        --name shamscontract \
        --version 1.0 \
        --sequence 1 \
        --orderer test-orderer.example.com:7150 \
        --peerAddresses test-peer0.shams.example.com:7151 \
        --peerAddresses test-peer0.rebar.example.com:9151

# بررسی chaincode committed
echo "✅ Checking committed chaincodes..."
exec_peer ShamsMSP \
    /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp \
    test-peer0.shams.example.com:7151 \
    peer lifecycle chaincode querycommitted --channelID "$CHANNEL_NAME"

echo "✅ Chaincode deployed successfully!"
