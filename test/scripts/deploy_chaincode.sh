#!/bin/bash
set -e

TEST_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${TEST_DIR}/scripts/env.sh"

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
    test-cli "$@"
}

echo "📦 Packaging chaincode..."
exec_cli ShamsMSP /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp test-peer0.shams.example.com:7151 \
  peer lifecycle chaincode package "${CC_NAME}.tar.gz" \
    --path /opt/gopath/src/github.com/chaincode \
    --lang node \
    --label "${CC_NAME}_${CC_VERSION}"

echo "🚀 Installing chaincode on Shams peer..."
exec_cli ShamsMSP /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp test-peer0.shams.example.com:7151 \
  peer lifecycle chaincode install "${CC_NAME}.tar.gz"

echo "🚀 Installing chaincode on Rebar peer..."
exec_cli RebarMSP /etc/hyperledger/crypto-config/peerOrganizations/rebar.example.com/users/Admin@rebar.example.com/msp test-peer0.rebar.example.com:9151 \
  peer lifecycle chaincode install "${CC_NAME}.tar.gz"

echo "🔍 Getting package ID..."
PACKAGE_ID=$(exec_cli ShamsMSP /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp test-peer0.shams.example.com:7151 \
  peer lifecycle chaincode queryinstalled | grep -o "${CC_NAME}_${CC_VERSION}:[a-f0-9]*" | head -1)

if [ -z "$PACKAGE_ID" ]; then
  echo "❌ Failed to get package ID"
  exit 1
fi

echo "📋 Package ID: $PACKAGE_ID"

echo "✅ Approving chaincode for Shams org..."
exec_cli ShamsMSP /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp test-peer0.shams.example.com:7151 \
  peer lifecycle chaincode approveformyorg \
    -o test-orderer.example.com:7150 \
    --channelID "${CHANNEL_NAME}" \
    --name "${CC_NAME}" \
    --version "${CC_VERSION}" \
    --package-id "${PACKAGE_ID}" \
    --sequence "${CC_SEQUENCE}" \
    --signature-policy "OR('ShamsMSP.peer','RebarMSP.peer')"

echo "✅ Approving chaincode for Rebar org..."
exec_cli RebarMSP /etc/hyperledger/crypto-config/peerOrganizations/rebar.example.com/users/Admin@rebar.example.com/msp test-peer0.rebar.example.com:9151 \
  peer lifecycle chaincode approveformyorg \
    -o test-orderer.example.com:7150 \
    --channelID "${CHANNEL_NAME}" \
    --name "${CC_NAME}" \
    --version "${CC_VERSION}" \
    --package-id "${PACKAGE_ID}" \
    --sequence "${CC_SEQUENCE}" \
    --signature-policy "OR('ShamsMSP.peer','RebarMSP.peer')"

echo "🔍 Checking commit readiness..."
exec_cli ShamsMSP /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp test-peer0.shams.example.com:7151 \
  peer lifecycle chaincode checkcommitreadiness \
    --channelID "${CHANNEL_NAME}" \
    --name "${CC_NAME}" \
    --version "${CC_VERSION}" \
    --sequence "${CC_SEQUENCE}" \
    --signature-policy "OR('ShamsMSP.peer','RebarMSP.peer')" \
    --output json

echo "🎯 Committing chaincode..."
exec_cli ShamsMSP /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp test-peer0.shams.example.com:7151 \
  peer lifecycle chaincode commit \
    -o test-orderer.example.com:7150 \
    --channelID "${CHANNEL_NAME}" \
    --name "${CC_NAME}" \
    --version "${CC_VERSION}" \
    --sequence "${CC_SEQUENCE}" \
    --signature-policy "OR('ShamsMSP.peer','RebarMSP.peer')" \
    --peerAddresses test-peer0.shams.example.com:7151 \
    --peerAddresses test-peer0.rebar.example.com:9151

echo "🔍 Querying committed chaincodes..."
exec_cli ShamsMSP /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp test-peer0.shams.example.com:7151 \
  peer lifecycle chaincode querycommitted --channelID "${CHANNEL_NAME}"

echo "✅ Chaincode deployment complete!"
