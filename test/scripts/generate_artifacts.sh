#!/bin/bash
set -e

TEST_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="${TEST_DIR}/config"
TOOLS_IMG="hyperledger/fabric-tools:2.5"

# بارگذاری متغیرها
source "${TEST_DIR}/scripts/env.sh"

echo "🧹 Cleaning old test artifacts..."
rm -rf "${CONFIG_DIR}/crypto-config" \
       "${CONFIG_DIR}"/*.block \
       "${CONFIG_DIR}"/*.tx

echo "🔨 Generating test crypto materials..."
docker run --rm -v "$TEST_DIR":/workspace -w /workspace \
    --platform linux/amd64 $TOOLS_IMG \
    cryptogen generate \
        --config=config/crypto-config.yaml \
        --output=config/crypto-config

echo "🧩 Generating genesis block (RebarGenesis profile)..."
docker run --rm -v "$TEST_DIR":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/config \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile RebarGenesis \
        -outputBlock config/genesis.block \
        -channelID system-channel

echo "📄 Generating channel creation transaction (RebarChannel profile)..."
docker run --rm -v "$TEST_DIR":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/config \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile RebarChannel \
        -outputCreateChannelTx config/${CHANNEL_NAME}.tx \
        -channelID ${CHANNEL_NAME}

echo "📍 Generating Anchor Peer Updates..."
docker run --rm -v "$TEST_DIR":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/config \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile RebarChannel \
        -outputAnchorPeersUpdate config/ShamsMSPanchors.tx \
        -asOrg ShamsOrg \
        -channelID ${CHANNEL_NAME}

docker run --rm -v "$TEST_DIR":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/config \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile RebarChannel \
        -outputAnchorPeersUpdate config/RebarMSPanchors.tx \
        -asOrg RebarOrg \
        -channelID ${CHANNEL_NAME}

echo "✅ Test artifacts generated in ${CONFIG_DIR}:"
ls -1 "${CONFIG_DIR}"
