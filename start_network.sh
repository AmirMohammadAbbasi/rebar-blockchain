#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$PROJECT_DIR/config"
CRYPTO_DIR="$PROJECT_DIR/crypto-config"
DOCKER_COMPOSE_FILE="$PROJECT_DIR/docker/docker-compose.yaml"
CHANNEL_NAME="rebar-channel"

echo "🚀 Generating certificates..."
docker run --rm -v "$PROJECT_DIR":"$PROJECT_DIR" -w "$PROJECT_DIR" hyperledger/fabric-tools:2.5 cryptogen generate --config="$CONFIG_DIR/crypto-config.yaml"

echo "🛠 Generating genesis block..."
docker run --rm -v "$PROJECT_DIR":"$PROJECT_DIR" -w "$PROJECT_DIR" hyperledger/fabric-tools:2.5 configtxgen -profile RebarGenesis -channelID system-channel -outputBlock "$PROJECT_DIR/genesis.block" -configPath "$CONFIG_DIR"

echo "📄 Generating channel transaction..."
docker run --rm -v "$PROJECT_DIR":"$PROJECT_DIR" -w "$PROJECT_DIR" hyperledger/fabric-tools:2.5 configtxgen -profile RebarChannel -outputCreateChannelTx "$PROJECT_DIR/${CHANNEL_NAME}.tx" -channelID $CHANNEL_NAME -configPath "$CONFIG_DIR"

echo "📍 Generating anchor peer updates..."
docker run --rm -v "$PROJECT_DIR":"$PROJECT_DIR" -w "$PROJECT_DIR" hyperledger/fabric-tools:2.5 configtxgen -profile RebarChannel -outputAnchorPeersUpdate "$PROJECT_DIR/ShamsOrgMSPanchors.tx" -asOrg ShamsOrg -channelID $CHANNEL_NAME -configPath "$CONFIG_DIR"

docker run --rm -v "$PROJECT_DIR":"$PROJECT_DIR" -w "$PROJECT_DIR" hyperledger/fabric-tools:2.5 configtxgen -profile RebarChannel -outputAnchorPeersUpdate "$PROJECT_DIR/RebarOrgMSPanchors.tx" -asOrg RebarOrg -channelID $CHANNEL_NAME -configPath "$CONFIG_DIR"

echo "🐳 Starting network..."
docker compose -f "$DOCKER_COMPOSE_FILE" up -d

echo "✅ Network is up and running!"
