#!/bin/bash
set -e
source ./scripts/env.sh

echo "🔨 Generating crypto materials..."
docker run --rm -v "${PWD}":/workspace -w /workspace \
    --platform linux/amd64 $TOOLS_IMG \
    cryptogen generate \
        --config=config/crypto-config.yaml \
        --output=config/crypto-config

echo "🧩 Generating genesis block..."
docker run --rm -v "${PWD}":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/config \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile RebarGenesis \
        -outputBlock config/genesis.block \
        -channelID system-channel

echo "📄 Generating channel tx..."
docker run --rm -v "${PWD}":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/config \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile RebarChannel \
        -outputCreateChannelTx config/${CHANNEL_NAME}.tx \
        -channelID ${CHANNEL_NAME}

echo "📍 Generating Anchor Peer Updates..."
docker run --rm -v "${PWD}":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/config \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile RebarChannel \
        -outputAnchorPeersUpdate config/ShamsMSPanchors.tx \
        -asOrg ShamsOrg \
        -channelID ${CHANNEL_NAME}

docker run --rm -v "${PWD}":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/config \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile RebarChannel \
        -outputAnchorPeersUpdate config/RebarMSPanchors.tx \
        -asOrg RebarOrg \
        -channelID ${CHANNEL_NAME}

echo "✅ All artifacts generated in ./config:"
ls -1 config
