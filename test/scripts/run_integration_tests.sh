#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/env.sh"

# ==== Variables for TEST network ====
ORDERER_NAME=test-orderer.example.com
ORDERER_PORT=7150
PEER_SHAMS=test-peer0.shams.example.com
PEER_REBAR=test-peer0.rebar.example.com
CLI_CONTAINER=test-cli

CHANNEL_BLOCK="$ROOT_DIR/config/test/${CHANNEL_NAME}.block"
CHAINCODE_TAR="$ROOT_DIR/rebarcc.tar.gz"
CHAINCODE_LABEL=${CC_NAME}_${CC_VERSION}

# ==== Helper functions ====
wait_for_dns() {
    local container=$1
    local host=$2
    echo "⏳ Waiting for $host to resolve inside $container..."
    for i in {1..30}; do
        if docker exec "$container" getent hosts "$host" >/dev/null; then
            echo "✅ $host resolved"
            return
        fi
        sleep 2
    done
    echo "❌ Timeout: $host not resolvable"
    exit 1
}

wait_for_port() {
    local container=$1
    local host=$2
    local port=$3
    echo "⏳ Waiting for $host:$port ..."
    for i in {1..60}; do
        if docker exec "$container" bash -c "nc -z $host $port" >/dev/null 2>&1; then
            echo "✅ $host:$port reachable"
            return
        fi
        sleep 2
    done
    echo "❌ Timeout: $host:$port not reachable"
    exit 1
}

peer_exec() {
    local container=$1
    shift
    docker exec \
        -e CORE_PEER_TLS_ENABLED=false \
        -e CORE_PEER_LOCALMSPID=$(echo "$container" | grep -qi shams && echo "ShamsMSP" || echo "RebarMSP") \
        -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/peer/msp \
        "$container" \
        peer "$@"
}

# ==== Step 0: Cleanup ====
docker network create fabric_net || true
docker compose -f "$ROOT_DIR/docker-compose.test.yaml" down -v || true

# ==== Step 1: Start TEST network ====
echo "🚀 Starting Fabric TEST network..."
docker compose -f "$ROOT_DIR/docker-compose.test.yaml" up -d $ORDERER_NAME $PEER_SHAMS $PEER_REBAR $CLI_CONTAINER

wait_for_dns "$PEER_SHAMS" "$ORDERER_NAME"
wait_for_port "$PEER_SHAMS" "$ORDERER_NAME" "$ORDERER_PORT"

# ==== Step 2: Create channel ====
peer_exec "$PEER_SHAMS" channel create \
    -o $ORDERER_NAME:$ORDERER_PORT \
    -c $CHANNEL_NAME \
    -f /var/hyperledger/config/test/${CHANNEL_NAME}.tx \
    --outputBlock /var/hyperledger/config/test/${CHANNEL_NAME}.block

# ==== Step 3: Join peers ====
peer_exec "$PEER_SHAMS" channel join -b /var/hyperledger/config/test/${CHANNEL_NAME}.block
peer_exec "$PEER_REBAR" channel join -b /var/hyperledger/config/test/${CHANNEL_NAME}.block

# ==== Step 4: Install chaincode ====
peer_exec "$PEER_SHAMS" lifecycle chaincode install /opt/gopath/src/github.com/chaincode/${CC_NAME}.tar.gz
peer_exec "$PEER_REBAR" lifecycle chaincode install /opt/gopath/src/github.com/chaincode/${CC_NAME}.tar.gz

# ==== Step 5: Query Package ID ====
PACKAGE_ID=$(peer_exec "$PEER_SHAMS" lifecycle chaincode queryinstalled | grep "$CHAINCODE_LABEL" | awk -F 'Package ID: ' '{print $2}' | awk -F ',' '{print $1}')
echo "📦 Package ID: $PACKAGE_ID"

# ==== Step 6: Approve chaincode ====
peer_exec "$PEER_SHAMS" lifecycle chaincode approveformyorg \
    -o $ORDERER_NAME:$ORDERER_PORT \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME \
    --version $CC_VERSION \
    --package-id $PACKAGE_ID \
    --sequence $CC_SEQUENCE

peer_exec "$PEER_REBAR" lifecycle chaincode approveformyorg \
    -o $ORDERER_NAME:$ORDERER_PORT \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME \
    --version $CC_VERSION \
    --package-id $PACKAGE_ID \
    --sequence $CC_SEQUENCE

# ==== Step 7: Commit chaincode ====
peer_exec "$PEER_SHAMS" lifecycle chaincode commit \
    -o $ORDERER_NAME:$ORDERER_PORT \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME \
    --version $CC_VERSION \
    --sequence $CC_SEQUENCE \
    --peerAddresses $PEER_SHAMS:7151 \
    --peerAddresses $PEER_REBAR:9151

# ==== Step 8: Init chaincode ====
peer_exec "$PEER_SHAMS" chaincode invoke \
    -o $ORDERER_NAME:$ORDERER_PORT \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME \
    -c '{"function":"Init","Args":[]}' \
    --waitForEvent

# ==== Step 9: Run integration tests ====
echo "🧪 Running integration tests..."
docker compose -f "$ROOT_DIR/docker-compose.test.yaml" run --rm test-runner

# ==== Step 10: Cleanup TEST network ====
docker compose -f "$ROOT_DIR/docker-compose.test.yaml" down -v
echo "🏁 Integration test flow completed successfully!"
