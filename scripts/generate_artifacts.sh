#!/bin/bash
set -e
source ./scripts/env.sh

ARTIFACTS_DIR=config

echo "🧹 Cleaning old artifacts..."
rm -rf ${ARTIFACTS_DIR}/crypto-config \
       ${ARTIFACTS_DIR}/*.block \
       ${ARTIFACTS_DIR}/*.tx

mkdir -p ${ARTIFACTS_DIR}

echo "🔨 Generating crypto materials..."
docker run --rm -v "${PWD}":/workspace -w /workspace \
    --platform linux/amd64 $TOOLS_IMG \
    cryptogen generate \
        --config=${ARTIFACTS_DIR}/crypto-config.yaml \
        --output=${ARTIFACTS_DIR}/crypto-config

echo "🧩 Generating genesis block..."
docker run --rm -v "${PWD}":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/${ARTIFACTS_DIR} \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile RebarGenesis \
        -outputBlock ${ARTIFACTS_DIR}/genesis.block \
        -channelID system-channel

echo "📄 Generating channel creation transaction..."
docker run --rm -v "${PWD}":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/${ARTIFACTS_DIR} \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile RebarChannel \
        -outputCreateChannelTx ${ARTIFACTS_DIR}/${CHANNEL_NAME}.tx \
        -channelID ${CHANNEL_NAME}

echo "📍 Generating Anchor Peer Updates..."
docker run --rm -v "${PWD}":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/${ARTIFACTS_DIR} \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile RebarChannel \
        -outputAnchorPeersUpdate ${ARTIFACTS_DIR}/ShamsMSPanchors.tx \
        -asOrg ShamsOrg \
        -channelID ${CHANNEL_NAME}

docker run --rm -v "${PWD}":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/${ARTIFACTS_DIR} \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile RebarChannel \
        -outputAnchorPeersUpdate ${ARTIFACTS_DIR}/RebarMSPanchors.tx \
        -asOrg RebarOrg \
        -channelID ${CHANNEL_NAME}

echo "✅ All artifacts generated in ${ARTIFACTS_DIR}:"
ls -1 ${ARTIFACTS_DIR}
