#!/bin/bash
set -euo pipefail
source ./scripts/env.sh

echo "🔨 Generating crypto materials & channel artifacts..."
docker run --rm -v "${PWD}":/workspace -w /workspace --platform linux/amd64 \
    $TOOLS_IMG cryptogen generate \
    --config=config/crypto-config.yaml --output=config/crypto-config

docker run --rm -v "${PWD}":/workspace -w /workspace --platform linux/amd64 \
    $TOOLS_IMG configtxgen -profile RebarGenesis \
    -outputBlock config/genesis.block -channelID system-channel

docker run --rm -v "${PWD}":/workspace -w /workspace --platform linux/amd64 \
    $TOOLS_IMG configtxgen -profile RebarChannel \
    -outputCreateChannelTx config/${CHANNEL_NAME}.tx -channelID ${CHANNEL_NAME}

echo "🚀 Starting network..."
docker-compose up -d orderer.example.com peer0.shams.example.com peer0.rebar.example.com
sleep 8

echo "📡 Creating channel..."
docker exec peer0.shams.example.com peer channel create \
    -o ${ORDERER_NAME}:${ORDERER_PORT} -c ${CHANNEL_NAME} \
    -f /opt/gopath/config/${CHANNEL_NAME}.tx \
    --outputBlock /opt/gopath/config/${CHANNEL_NAME}.block \
    --tls --cafile ${ORDERER_CA}

echo "📌 Joining Shams peer..."
docker exec peer0.shams.example.com peer channel join \
    -b /opt/gopath/config/${CHANNEL_NAME}.block

echo "📌 Joining Rebar peer..."
docker exec peer0.rebar.example.com peer channel join \
    -b /opt/gopath/config/${CHANNEL_NAME}.block

echo "📦 Packaging chaincode..."
docker exec peer0.shams.example.com peer lifecycle chaincode package ${CC_NAME}.tar.gz \
    --path /opt/gopath/src/github.com/chaincode --lang node --label ${CC_NAME}_${CC_VERSION}

echo "⬆ Installing on Shams peer..."
docker exec peer0.shams.example.com peer lifecycle chaincode install ${CC_NAME}.tar.gz

echo "⬆ Installing on Rebar peer..."
docker exec peer0.rebar.example.com peer lifecycle chaincode install ${CC_NAME}.tar.gz

PKG_ID=$(docker exec peer0.shams.example.com peer lifecycle chaincode queryinstalled | grep ${CC_NAME} | sed -n 's/Package ID: //; s/, Label:.*//p')

echo "✅ Approving for ShamsOrg..."
docker exec peer0.shams.example.com peer lifecycle chaincode approveformyorg \
    -o ${ORDERER_NAME}:${ORDERER_PORT} --channelID ${CHANNEL_NAME} \
    --name ${CC_NAME} --version ${CC_VERSION} --sequence ${CC_SEQUENCE} \
    --package-id "$PKG_ID" --tls --cafile ${ORDERER_CA}

echo "✅ Approving for RebarOrg..."
docker exec peer0.rebar.example.com peer lifecycle chaincode approveformyorg \
    -o ${ORDERER_NAME}:${ORDERER_PORT} --channelID ${CHANNEL_NAME} \
    --name ${CC_NAME} --version ${CC_VERSION} --sequence ${CC_SEQUENCE} \
    --package-id "$PKG_ID" --tls --cafile ${ORDERER_CA}

echo "🔗 Committing chaincode..."
docker exec peer0.shams.example.com peer lifecycle chaincode commit \
    -o ${ORDERER_NAME}:${ORDERER_PORT} --channelID ${CHANNEL_NAME} \
    --name ${CC_NAME} --version ${CC_VERSION} --sequence ${CC_SEQUENCE} \
    --tls --cafile ${ORDERER_CA} \
    --peerAddresses ${PEER0_SHAMS_ADDRESS} --peerAddresses ${PEER0_REBAR_ADDRESS}

echo "📦 Installing Node deps..."
npm install fabric-network@^2.2 --save-dev
npm install

echo "🧪 Running integration tests..."
npx mocha test/integration/*.js --exit

echo "🎉 All done successfully!"
