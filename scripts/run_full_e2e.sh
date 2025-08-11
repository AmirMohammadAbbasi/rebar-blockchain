#!/bin/bash
set -e
source ./scripts/env.sh

MODE=$1
CC_LABEL="${CC_NAME}_${CC_VERSION}"
CC_PACKAGE="./config/${CC_LABEL}.tar.gz"

function cleanup() {
  echo "🧹 Cleaning containers, volumes, and networks..."
  docker rm -f $(docker ps -aq) 2>/dev/null || true
  docker network prune -f
  docker volume prune -f
  rm -rf ./config/genesis.block ./config/crypto-config ./config/${CHANNEL_NAME}.tx \
         ./config/${CHANNEL_NAME}.block ./config/${CC_LABEL}.tar.gz
}

function generate_artifacts() {
  echo "⚙️ Generating fresh artifacts..."
  ./scripts/generate_artifacts.sh
}

function package_chaincode() {
  echo "📦 Packaging chaincode..."
  docker run --rm \
    -v ${PWD}:/workspace \
    -w /workspace/chaincode \
    --platform linux/amd64 $TOOLS_IMG \
    peer lifecycle chaincode package ../config/${CC_LABEL}.tar.gz \
      --path /workspace/chaincode \
      --lang node \
      --label ${CC_LABEL}
}

function start_network() {
  echo "🚀 Starting containers..."
  docker compose up -d

  echo "⏳ Waiting for orderer DNS..."
  docker exec peer0.shams.example.com sh -c "for i in \$(seq 1 15); do getent hosts orderer.example.com && exit 0 || sleep 2; done; exit 1"

  echo "⏳ Checking orderer availability via peer CLI..."
  docker exec cli sh -c "for i in \$(seq 1 15); do peer channel list -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile /var/hyperledger/orderer/tls/ca.crt >/dev/null 2>&1 && exit 0 || sleep 2; done; exit 1"
}

function create_channel() {
  echo "📡 Creating channel ${CHANNEL_NAME}..."
  docker exec cli peer channel create \
    -o orderer.example.com:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    -c ${CHANNEL_NAME} \
    -f /var/hyperledger/configs/${CHANNEL_NAME}.tx \
    --outputBlock /var/hyperledger/configs/${CHANNEL_NAME}.block \
    --tls \
    --cafile /var/hyperledger/orderer/tls/ca.crt
}

function join_peers() {
  echo "🤝 Joining peers to channel..."
  docker exec cli peer channel join -b /var/hyperledger/configs/${CHANNEL_NAME}.block
  docker exec -e CORE_PEER_ADDRESS=peer0.rebar.example.com:9051 cli \
    peer channel join -b /var/hyperledger/configs/${CHANNEL_NAME}.block
}

function install_chaincode() {
  echo "📦 Installing chaincode on Shams peer..."
  docker exec cli peer lifecycle chaincode install /var/hyperledger/configs/${CC_LABEL}.tar.gz
  echo "📦 Installing chaincode on Rebar peer..."
  docker exec -e CORE_PEER_ADDRESS=peer0.rebar.example.com:9051 cli \
    peer lifecycle chaincode install /var/hyperledger/configs/${CC_LABEL}.tar.gz
}

function approve_chaincode() {
  echo "✅ Approving chaincode for ShamsMSP..."
  PID=$(docker exec cli peer lifecycle chaincode queryinstalled | grep ${CC_LABEL} | awk '{print $3}' | sed 's/,$//')
  docker exec cli peer lifecycle chaincode approveformyorg \
    -o orderer.example.com:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile /var/hyperledger/orderer/tls/ca.crt \
    --channelID ${CHANNEL_NAME} \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --sequence ${CC_SEQUENCE} \
    --init-required \
    --package-id ${PID}

  echo "✅ Approving chaincode for RebarMSP..."
  docker exec -e CORE_PEER_ADDRESS=peer0.rebar.example.com:9051 cli \
    peer lifecycle chaincode approveformyorg \
    -o orderer.example.com:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile /var/hyperledger/orderer/tls/ca.crt \
    --channelID ${CHANNEL_NAME} \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --sequence ${CC_SEQUENCE} \
    --init-required \
    --package-id ${PID}
}

function commit_chaincode() {
  echo "📜 Committing chaincode..."
  docker exec cli peer lifecycle chaincode commit \
    -o orderer.example.com:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile /var/hyperledger/orderer/tls/ca.crt \
    --channelID ${CHANNEL_NAME} \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --sequence ${CC_SEQUENCE} \
    --init-required \
    --peerAddresses peer0.shams.example.com:7051 \
    --tlsRootCertFiles /var/hyperledger/peerOrganizations/shams.example.com/peers/peer0.shams.example.com/tls/ca.crt \
    --peerAddresses peer0.rebar.example.com:9051 \
    --tlsRootCertFiles /var/hyperledger/peerOrganizations/rebar.example.com/peers/peer0.rebar.example.com/tls/ca.crt
}

function init_chaincode() {
  echo "🚦 Initializing chaincode..."
  docker exec cli peer chaincode invoke \
    -o orderer.example.com:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile /var/hyperledger/orderer/tls/ca.crt \
    -C ${CHANNEL_NAME} \
    -n ${CC_NAME} \
    --isInit \
    -c '{"Args":["Init"]}' \
    --waitForEvent
}

### MAIN
if [[ "$MODE" == "--full" ]]; then
  cleanup
  generate_artifacts
  package_chaincode
  start_network
elif [[ "$MODE" == "--fast" ]]; then
  package_chaincode
  start_network
else
  echo "Usage: $0 [--full|--fast]"
  exit 1
fi

create_channel
join_peers
install_chaincode
approve_chaincode
commit_chaincode
init_chaincode

echo "🏁 E2E setup completed! Chaincode ${CC_NAME} v${CC_VERSION} committed and initialized."
