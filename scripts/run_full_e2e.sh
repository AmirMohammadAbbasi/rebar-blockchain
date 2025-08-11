#!/usr/bin/env bash
set -euo pipefail

source ./scripts/env.sh

ORDERER_NAME=orderer.example.com
PEER_SHAMS=peer0.shams.example.com
PEER_REBAR=peer0.rebar.example.com
ORDERER_PORT=7050
CHANNEL_BLOCK=./config/${CHANNEL_NAME}.block
CHAINCODE_TAR=rebarcc.tar.gz
CHAINCODE_LABEL=${CC_NAME}_${CC_VERSION}

wait_for_dns() {
    local container=$1
    local host=$2
    echo "⏳ Waiting for $host to resolve inside $container..."
    for i in {1..30}; do
        if docker exec "$container" getent hosts "$host" >/dev/null; then
            echo "✅ $host resolved."
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
    echo "⏳ Waiting for $host:$port to be reachable inside $container..."
    for i in {1..60}; do  # 2 minutes max
        if docker exec "$container" sh -c "exec 3<>/dev/tcp/$host/$port" 2>/dev/null; then
            echo "✅ $host:$port reachable."
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
        -e CORE_PEER_TLS_ENABLED=true \
        -e CORE_PEER_LOCALMSPID=$(echo "$container" | grep -qi shams && echo "ShamsMSP" || echo "RebarMSP") \
        -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/msp \
        -e CORE_PEER_TLS_ROOTCERT_FILE=/var/hyperledger/tls/ca.crt \
        "$container" \
        peer "$@"
}

echo "🏁 Starting full E2E flow..."

# فقط DNS و پورت Orderer رو چک می‌کنیم
wait_for_dns "$PEER_SHAMS" "$ORDERER_NAME"
# wait_for_port "$PEER_SHAMS" "$ORDERER_NAME" "$ORDERER_PORT"

echo "📦 Creating channel..."
peer_exec "$PEER_SHAMS" channel create \
    -o $ORDERER_NAME:$ORDERER_PORT \
    --ordererTLSHostnameOverride $ORDERER_NAME \
    -c $CHANNEL_NAME \
    -f ./config/${CHANNEL_NAME}.tx \
    --outputBlock $CHANNEL_BLOCK \
    --tls --cafile /var/hyperledger/tls/orderer-ca.crt

echo "🔗 Joining Shams peer..."
peer_exec "$PEER_SHAMS" channel join -b $CHANNEL_BLOCK

echo "🔗 Joining Rebar peer..."
wait_for_dns "$PEER_REBAR" "$ORDERER_NAME"
peer_exec "$PEER_REBAR" channel join -b $CHANNEL_BLOCK

echo "📥 Installing chaincode on Shams peer..."
peer_exec "$PEER_SHAMS" lifecycle chaincode install $CHAINCODE_TAR

echo "📥 Installing chaincode on Rebar peer..."
peer_exec "$PEER_REBAR" lifecycle chaincode install $CHAINCODE_TAR

PACKAGE_ID=$(peer_exec "$PEER_SHAMS" lifecycle chaincode queryinstalled | \
    grep "$CHAINCODE_LABEL" | awk -F 'Package ID: ' '{print $2}' | awk -F ',' '{print $1}')
echo "📦 Package ID: $PACKAGE_ID"

echo "✅ Approving chaincode on Shams peer..."
peer_exec "$PEER_SHAMS" lifecycle chaincode approveformyorg \
    -o $ORDERER_NAME:$ORDERER_PORT \
    --ordererTLSHostnameOverride $ORDERER_NAME \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME \
    --version $CC_VERSION \
    --package-id $PACKAGE_ID \
    --sequence $CC_SEQUENCE \
    --tls --cafile /var/hyperledger/tls/orderer-ca.crt

echo "✅ Approving chaincode on Rebar peer..."
peer_exec "$PEER_REBAR" lifecycle chaincode approveformyorg \
    -o $ORDERER_NAME:$ORDERER_PORT \
    --ordererTLSHostnameOverride $ORDERER_NAME \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME \
    --version $CC_VERSION \
    --package-id $PACKAGE_ID \
    --sequence $CC_SEQUENCE \
    --tls --cafile /var/hyperledger/tls/orderer-ca.crt

echo "🚀 Committing chaincode..."
peer_exec "$PEER_SHAMS" lifecycle chaincode commit \
    -o $ORDERER_NAME:$ORDERER_PORT \
    --ordererTLSHostnameOverride $ORDERER_NAME \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME \
    --version $CC_VERSION \
    --sequence $CC_SEQUENCE \
    --tls --cafile /var/hyperledger/tls/orderer-ca.crt \
    --peerAddresses $PEER_SHAMS:7051 \
    --tlsRootCertFiles /var/hyperledger/tls/ca.crt \
    --peerAddresses $PEER_REBAR:7051 \
    --tlsRootCertFiles /var/hyperledger/tls/ca.crt

echo "⚡ Invoking Init..."
peer_exec "$PEER_SHAMS" chaincode invoke \
    -o $ORDERER_NAME:$ORDERER_PORT \
    --ordererTLSHostnameOverride $ORDERER_NAME \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME \
    -c '{"function":"Init","Args":[]}' \
    --tls --cafile /var/hyperledger/tls/orderer-ca.crt \
    --waitForEvent

echo "✅ E2E flow completed successfully!"
