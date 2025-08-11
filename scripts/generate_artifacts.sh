#!/bin/bash
set -e
source ./scripts/env.sh

echo "🔨 Generating crypto materials..."
docker run --rm -v "${PWD}":/workspace -w /workspace \
    --platform linux/amd64 $TOOLS_IMG \
    cryptogen generate --config=config/crypto-config.yaml --output=config/crypto-config

echo "🧩 Generating genesis block..."
docker run --rm -v "${PWD}":/workspace -w /workspace \
    --platform linux/amd64 -e FABRIC_CFG_PATH=/workspace/config $TOOLS_IMG \
    configtxgen -profile RebarGenesis \
    -outputBlock config/genesis.block \
    -channelID system-channel

echo "📄 Generating channel tx..."
docker run --rm -v "${PWD}":/workspace -w /workspace \
    --platform linux/amd64 -e FABRIC_CFG_PATH=/workspace/config $TOOLS_IMG \
    configtxgen -profile RebarChannel \
    -outputCreateChannelTx config/${CHANNEL_NAME}.tx \
    -channelID ${CHANNEL_NAME}
