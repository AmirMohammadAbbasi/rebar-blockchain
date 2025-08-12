#!/usr/bin/env bash
set -euo pipefail

# مسیر root پروژه
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/env.sh"

# ==== Container & Hostnames ====
ORDERER_NAME=orderer.example.com
ORDERER_PORT=7050
PEER_SHAMS=peer0.shams.example.com
PEER_REBAR=peer0.rebar.example.com

CHANNEL_BLOCK="$ROOT_DIR/config/${CHANNEL_NAME}.block"
CHAINCODE_TAR="$ROOT_DIR/rebarcc.tar.gz"
CHAINCODE_LABEL=${CC_NAME}_${CC_VERSION}

# ===== Helper functions =====
wait_for_dns() {
    local container=$1
    local host=$2
    echo "⏳ منتظر resolve شدن $host داخل $container ..."
    for i in {1..30}; do
        if docker exec "$container" getent hosts "$host" >/dev/null; then
            echo "✅ $host resolved inside $container"
            return
        fi
        sleep 2
    done
    echo "❌ Timeout: $host not resolvable in $container"
    exit 1
}

wait_for_port() {
    local container=$1
    local host=$2
    local port=$3
    echo "⏳ منتظر در دسترس بودن پورت $port روی $host داخل $container ..."
    for i in {1..60}; do
        if docker exec "$container" bash -c "nc -z $host $port" >/dev/null 2>&1; then
            echo "✅ $host:$port reachable from $container"
            return
        fi
        sleep 2
    done
    echo "❌ Timeout: $host:$port not reachable in $container"
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

# ==== Step 0: Setup network ====
docker network create fabric_net || true
docker compose -f "$ROOT_DIR/docker-compose.yaml" down -v || true
docker compose -f "$ROOT_DIR/docker-compose.test.yaml" down -v || true

echo "🚀 Starting main Fabric TLS network..."
docker compose -f "$ROOT_DIR/docker-compose.yaml" up -d

# ==== Step 1: انتظار برای آماده شدن سرویس‌ها ====
wait_for_dns "$PEER_SHAMS" "$ORDERER_NAME"
wait_for_port "$PEER_SHAMS" "$ORDERER_NAME" "$ORDERER_PORT"

# ==== Step 2: ایجاد کانال ====
echo "📦 Creating channel..."
peer_exec "$PEER_SHAMS" channel create \
    -o $ORDERER_NAME:$ORDERER_PORT \
    -c $CHANNEL_NAME \
    -f ./config/${CHANNEL_NAME}.tx \
    --outputBlock $CHANNEL_BLOCK

# ==== Step 3: Join Peers ====
echo "🔗 Joining Shams peer..."
peer_exec "$PEER_SHAMS" channel join -b $CHANNEL_BLOCK

echo "🔗 Joining Rebar peer..."
wait_for_dns "$PEER_REBAR" "$ORDERER_NAME"
peer_exec "$PEER_REBAR" channel join -b $CHANNEL_BLOCK

# ==== Step 4: نصب chaincode ====
echo "📥 Installing chaincode on Shams peer..."
peer_exec "$PEER_SHAMS" lifecycle chaincode install $CHAINCODE_TAR

echo "📥 Installing chaincode on Rebar peer..."
peer_exec "$PEER_REBAR" lifecycle chaincode install $CHAINCODE_TAR

# ==== Step 5: گرفتن Package ID ====
PACKAGE_ID=$(peer_exec "$PEER_SHAMS" lifecycle chaincode queryinstalled | \
    grep "$CHAINCODE_LABEL" | awk -F 'Package ID: ' '{print $2}' | awk -F ',' '{print $1}')
echo "📦 Package ID: $PACKAGE_ID"

# ==== Step 6: Approve for each org ====
echo "✅ Approving chaincode on Shams peer..."
peer_exec "$PEER_SHAMS" lifecycle chaincode approveformyorg \
    -o $ORDERER_NAME:$ORDERER_PORT \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME \
    --version $CC_VERSION \
    --package-id $PACKAGE_ID \
    --sequence $CC_SEQUENCE

echo "✅ Approving chaincode on Rebar peer..."
peer_exec "$PEER_REBAR" lifecycle chaincode approveformyorg \
    -o $ORDERER_NAME:$ORDERER_PORT \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME \
    --version $CC_VERSION \
    --package-id $PACKAGE_ID \
    --sequence $CC_SEQUENCE

# ==== Step 7: Commit ====
echo "🚀 Committing chaincode..."
peer_exec "$PEER_SHAMS" lifecycle chaincode commit \
    -o $ORDERER_NAME:$ORDERER_PORT \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME \
    --version $CC_VERSION \
    --sequence $CC_SEQUENCE \
    --peerAddresses $PEER_SHAMS:7051 \
    --peerAddresses $PEER_REBAR:9051

# ==== Step 8: Init chaincode ====
echo "⚡ Invoking Init..."
peer_exec "$PEER_SHAMS" chaincode invoke \
    -o $ORDERER_NAME:$ORDERER_PORT \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME \
    -c '{"function":"Init","Args":[]}' \
    --waitForEvent

# ==== Step 9: Run integration tests ====
echo "🧪 Running integration tests..."
docker compose -f "$ROOT_DIR/docker-compose.test.yaml" up --abort-on-container-exit
docker compose -f "$ROOT_DIR/docker-compose.test.yaml" down -v

# ==== Step 10: Cleanup main network ====
docker compose -f "$ROOT_DIR/docker-compose.yaml" down -v

echo "✅ Full E2E flow completed successfully!"
