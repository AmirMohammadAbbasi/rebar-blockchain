#!/bin/bash
set -e

TEST_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$TEST_DIR/scripts/env.sh"

echo "📦 Packaging chaincode..."
docker exec test-cli \
  peer lifecycle chaincode package ${CC_NAME}.tar.gz \
    --path ${CC_SRC_PATH} \
    --lang node \
    --label ${CC_NAME}_${CC_VERSION}

# تابع اجرا داخل CLI
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

# ==== نصب روی Shams ====
echo "📥 Installing chaincode on Shams peer..."
exec_cli \
  ShamsMSP \
  /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp \
  test-peer0.shams.example.com:7151 \
  peer lifecycle chaincode install ${CC_NAME}.tar.gz

# ==== نصب روی Rebar ====
echo "📥 Installing chaincode on Rebar peer..."
exec_cli \
  RebarMSP \
  /etc/hyperledger/crypto-config/peerOrganizations/rebar.example.com/users/Admin@rebar.example.com/msp \
  test-peer0.rebar.example.com:9151 \
  peer lifecycle chaincode install ${CC_NAME}.tar.gz

# گرفتن package ID از Shams (هر دو یکیه)  
PACKAGE_ID=$(docker exec test-cli \
  peer lifecycle chaincode queryinstalled | grep "${CC_NAME}_${CC_VERSION}" | sed -n 's/^Package ID: \(.*\), Label:.*$/\1/p')

# ==== Approve برای Shams ====
echo "✅ Approving chaincode for Shams..."
exec_cli \
  ShamsMSP \
  /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp \
  test-peer0.shams.example.com:7151 \
  peer lifecycle chaincode approveformyorg \
    --channelID ${CHANNEL_NAME} \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --package-id ${PACKAGE_ID} \
    --sequence ${CC_SEQUENCE} \
    --init-required \
    -o test-orderer.example.com:7150

# ==== Approve برای Rebar ====
echo "✅ Approving chaincode for Rebar..."
exec_cli \
  RebarMSP \
  /etc/hyperledger/crypto-config/peerOrganizations/rebar.example.com/users/Admin@rebar.example.com/msp \
  test-peer0.rebar.example.com:9151 \
  peer lifecycle chaincode approveformyorg \
    --channelID ${CHANNEL_NAME} \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --package-id ${PACKAGE_ID} \
    --sequence ${CC_SEQUENCE} \
    --init-required \
    -o test-orderer.example.com:7150

# ==== Commit chaincode ====
echo "📦 Committing chaincode to channel..."
exec_cli \
  ShamsMSP \
  /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp \
  test-peer0.shams.example.com:7151 \
  peer lifecycle chaincode commit \
    --channelID ${CHANNEL_NAME} \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --sequence ${CC_SEQUENCE} \
    --init-required \
    -o test-orderer.example.com:7150 \
    --peerAddresses test-peer0.shams.example.com:7151 \
    --peerAddresses test-peer0.rebar.example.com:9151

# ==== Init chaincode ====
echo "🚀 Initializing chaincode..."
exec_cli \
  ShamsMSP \
  /etc/hyperledger/crypto-config/peerOrganizations/shams.example.com/users/Admin@shams.example.com/msp \
  test-peer0.shams.example.com:7151 \
  peer chaincode invoke \
    -o test-orderer.example.com:7150 \
    --channelID ${CHANNEL_NAME} \
    --name ${CC_NAME} \
    --isInit \
    -c '{"Args":[]}' \
    --waitForEvent

echo "✅ Chaincode deployed & initialized successfully."
