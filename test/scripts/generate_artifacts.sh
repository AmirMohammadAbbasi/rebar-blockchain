#!/bin/bash
set -e

TEST_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARTIFACTS_DIR="${TEST_DIR}/artifacts"
TOOLS_IMG="hyperledger/fabric-tools:2.5"
CHANNEL_NAME="testchannel"

echo "🧹 Cleaning old TEST artifacts..."
rm -rf "${ARTIFACTS_DIR}"
mkdir -p "${ARTIFACTS_DIR}"

echo "📄 Copying configtx.yaml to artifacts..."
cp "${TEST_DIR}/config/configtx.yaml" "${ARTIFACTS_DIR}/"

echo "🔨 Generating TEST crypto materials..."
docker run --rm -v "$TEST_DIR":/workspace -w /workspace \
    --platform linux/amd64 $TOOLS_IMG \
    cryptogen generate \
        --config=config/crypto-config.yaml \
        --output="artifacts/crypto-config"

echo "🧩 Generating TEST genesis block (solo, no TLS)..."
docker run --rm -v "$TEST_DIR":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/artifacts \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile TestGenesis \
        -outputBlock "artifacts/genesis.block" \
        -channelID system-channel

echo "📄 Generating TEST channel creation transaction..."
docker run --rm -v "$TEST_DIR":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/artifacts \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile TestChannel \
        -outputCreateChannelTx "artifacts/${CHANNEL_NAME}.tx" \
        -channelID ${CHANNEL_NAME}

echo "📍 Generating TEST Anchor Peer Updates..."
docker run --rm -v "$TEST_DIR":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/artifacts \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile TestChannel \
        -outputAnchorPeersUpdate "artifacts/ShamsMSPanchors.tx" \
        -asOrg ShamsOrg \
        -channelID ${CHANNEL_NAME}

docker run --rm -v "$TEST_DIR":/workspace -w /workspace \
    -e FABRIC_CFG_PATH=/workspace/artifacts \
    --platform linux/amd64 $TOOLS_IMG \
    configtxgen \
        -profile TestChannel \
        -outputAnchorPeersUpdate "artifacts/RebarMSPanchors.tx" \
        -asOrg RebarOrg \
        -channelID ${CHANNEL_NAME}

echo "✅ TEST artifacts generated in ${ARTIFACTS_DIR}:"
ls -1 "${ARTIFACTS_DIR}"
