#!/bin/bash
set -e

TEST_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARTIFACTS_DIR="$TEST_DIR/config/artifacts"
TOOLS_IMG="hyperledger/fabric-tools:2.5"
CHANNEL_NAME="testchannel"

echo "🧹 Cleaning old TEST artifacts..."
rm -rf ${ARTIFACTS_DIR}
mkdir -p ${ARTIFACTS_DIR}

echo "🔨 Generating TEST crypto materials..."
docker run --rm -v "$TEST_DIR":/workspace -w /workspace \
    --platform linux/amd64 $TOOLS_IMG \
    cryptogen generate \
        --config=config/crypto-config.yaml \
        --output=config/artifacts/crypto-config

echo "🧩 Generating TEST genesis block..."
docker run --rm -v "$TEST_DIR":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/config \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile TestGenesis \
        -outputBlock config/artifacts/genesis.block \
        -channelID system-channel

echo "📄 Generating TEST channel creation transaction..."
docker run --rm -v "$TEST_DIR":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/config \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile TestChannel \
        -outputCreateChannelTx config/artifacts/${CHANNEL_NAME}.tx \
        -channelID ${CHANNEL_NAME}

echo "📍 Generating TEST Anchor Peer Updates..."
docker run --rm -v "$TEST_DIR":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/config \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile TestChannel \
        -outputAnchorPeersUpdate config/artifacts/ShamsMSPanchors.tx \
        -asOrg ShamsOrg \
        -channelID ${CHANNEL_NAME}

docker run --rm -v "$TEST_DIR":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/config \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile TestChannel \
        -outputAnchorPeersUpdate config/artifacts/RebarMSPanchors.tx \
        -asOrg RebarOrg \
        -channelID ${CHANNEL_NAME}

echo "✅ All TEST artifacts generated in ${ARTIFACTS_DIR}"
ls -1 ${ARTIFACTS_DIR}
