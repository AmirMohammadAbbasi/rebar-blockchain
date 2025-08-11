#!/bin/bash
set -euo pipefail

# CONFIG
COMPOSE_FILE=docker-compose.yaml
CHANNEL_NAME=rebarchannel
CC_NAME=rebarcc
CC_VERSION=1.0
CC_SEQUENCE=1
TOOLS_IMG=hyperledger/fabric-tools:2.5

echo "🛑 پاکسازی شبکه قبلی (در صورت وجود)..."
docker-compose -f "$COMPOSE_FILE" down -v || true

echo "🚀 راه‌اندازی کانتینرها (orderer + peers)..."
docker-compose -f "$COMPOSE_FILE" up -d orderer.example.com peer0.shams.example.com peer0.rebar.example.com

echo "⏳ منتظر آماده‌سازی سرویس‌ها..."
sleep 12

echo "🔨 تولید crypto materials و artifacts (با تنظیم FABRIC_CFG_PATH)..."
# مطمئن شو دایرکتوری config وجود داره و configtx.yaml داخلشه
if [ ! -f ./config/configtx.yaml ]; then
  echo "❌ فایل config/configtx.yaml پیدا نشد. لطفاً آن را در مسیر درست قرار بده."
  exit 1
fi

# cryptogen
docker run --rm -v "${PWD}":/workspace -w /workspace \
  --platform linux/amd64 $TOOLS_IMG \
  sh -c "export FABRIC_CFG_PATH=/workspace/config && cryptogen generate --config=config/crypto-config.yaml --output=config/crypto-config"

# configtxgen genesis.block
docker run --rm -v "${PWD}":/workspace -w /workspace \
  --platform linux/amd64 $TOOLS_IMG \
  sh -c "export FABRIC_CFG_PATH=/workspace/config && configtxgen -profile RebarGenesis -outputBlock config/genesis.block -channelID system-channel"

# configtxgen channel tx
docker run --rm -v "${PWD}":/workspace -w /workspace \
  --platform linux/amd64 $TOOLS_IMG \
  sh -c "export FABRIC_CFG_PATH=/workspace/config && configtxgen -profile RebarChannel -outputCreateChannelTx config/${CHANNEL_NAME}.tx -channelID ${CHANNEL_NAME}"

echo "📦 کپی genesis.block و channel.tx به کانتینرها..."
docker cp config/genesis.block orderer.example.com:/var/hyperledger/config/genesis.block
docker cp config/${CHANNEL_NAME}.tx peer0.shams.example.com:/var/hyperledger/config/${CHANNEL_NAME}.tx
docker cp config/${CHANNEL_NAME}.tx peer0.rebar.example.com:/var/hyperledger/config/${CHANNEL_NAME}.tx

echo "📡 ساخت کانال (از peer0.shams)..."
docker exec peer0.shams.example.com peer channel create \
  -o orderer.example.com:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  -c $CHANNEL_NAME \
  -f /var/hyperledger/config/${CHANNEL_NAME}.tx \
  --outputBlock /var/hyperledger/config/${CHANNEL_NAME}.block \
  --tls \
  --cafile /var/hyperledger/tls/ca.crt

echo "📥 peer0.shams joining channel..."
docker exec peer0.shams.example.com peer channel join -b /var/hyperledger/config/${CHANNEL_NAME}.block

echo "📥 peer0.rebar joining channel..."
docker cp config/${CHANNEL_NAME}.block peer0.rebar.example.com:/var/hyperledger/config/${CHANNEL_NAME}.block
docker exec peer0.rebar.example.com peer channel join -b /var/hyperledger/config/${CHANNEL_NAME}.block

echo "📦 پکیج کردن chaincode محلی..."
# بسته‌بندی ساده: tar gzip از محتویات پوشه chaincode
if [ ! -d ./chaincode ]; then
  echo "❌ پوشه chaincode وجود ندارد."
  exit 1
fi
tar -czf ${CC_NAME}.tar.gz -C chaincode .

echo "📤 نصب chaincode روی peer0.shams..."
docker cp ${CC_NAME}.tar.gz peer0.shams.example.com:/opt/gopath/src/github.com/chaincode/${CC_NAME}.tar.gz
docker exec peer0.shams.example.com peer lifecycle chaincode install /opt/gopath/src/github.com/chaincode/${CC_NAME}.tar.gz

echo "📤 نصب chaincode روی peer0.rebar..."
docker cp ${CC_NAME}.tar.gz peer0.rebar.example.com:/opt/gopath/src/github.com/chaincode/${CC_NAME}.tar.gz
docker exec peer0.rebar.example.com peer lifecycle chaincode install /opt/gopath/src/github.com/chaincode/${CC_NAME}.tar.gz

echo "🔍 گرفتن PACKAGE_ID از peer0.shams..."
PKG_ID=$(docker exec peer0.shams.example.com peer lifecycle chaincode queryinstalled | grep "${CC_NAME}" | sed -n 's/Package ID: \(.*\), Label.*/\1/p' || true)
if [ -z "$PKG_ID" ]; then
  echo "❌ نتوانست PACKAGE ID را بیابد. خروجی queryinstalled:"
  docker exec peer0.shams.example.com peer lifecycle chaincode queryinstalled || true
  exit 1
fi
echo "📦 PACKAGE_ID=${PKG_ID}"

echo "✅ approve chaincode برای ShamsMSP..."
docker exec peer0.shams.example.com peer lifecycle chaincode approveformyorg \
  -o orderer.example.com:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --channelID $CHANNEL_NAME \
  --name $CC_NAME \
  --version $CC_VERSION \
  --package-id $PKG_ID \
  --sequence $CC_SEQUENCE \
  --tls \
  --cafile /var/hyperledger/tls/ca.crt

echo "✅ approve chaincode برای RebarMSP..."
docker exec peer0.rebar.example.com peer lifecycle chaincode approveformyorg \
  -o orderer.example.com:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --channelID $CHANNEL_NAME \
  --name $CC_NAME \
  --version $CC_VERSION \
  --package-id $PKG_ID \
  --sequence $CC_SEQUENCE \
  --tls \
  --cafile /var/hyperledger/tls/ca.crt

echo "📜 commit chaincode..."
docker exec peer0.shams.example.com peer lifecycle chaincode commit \
  -o orderer.example.com:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --channelID $CHANNEL_NAME \
  --name $CC_NAME \
  --version $CC_VERSION \
  --sequence $CC_SEQUENCE \
  --tls \
  --cafile /var/hyperledger/tls/ca.crt \
  --peerAddresses peer0.shams.example.com:7051 \
  --tlsRootCertFiles /var/hyperledger/tls/ca.crt \
  --peerAddresses peer0.rebar.example.com:9051 \
  --tlsRootCertFiles /var/hyperledger/tls/ca.crt

echo "🎉 شبکه و chaincode آماده است!"
