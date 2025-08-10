#!/bin/bash
set -e
source ./scripts/env.sh

# نصب روی ShamsOrg
docker exec peer0.shams.example.com peer lifecycle chaincode package ${CC_NAME}.tar.gz --path /opt/gopath/src/github.com/chaincode --lang node --label ${CC_NAME}_${CC_VERSION}
docker exec peer0.shams.example.com peer lifecycle chaincode install ${CC_NAME}.tar.gz

# نصب روی RebarOrg
docker exec peer0.rebar.example.com peer lifecycle chaincode install ${CC_NAME}.tar.gz

# گرفتن package ID برای approve
PKG_ID=$(docker exec peer0.shams.example.com peer lifecycle chaincode queryinstalled | grep ${CC_NAME} | sed -n 's/Package ID: //; s/, Label:.*//p')

# Approve برای هر Org
docker exec peer0.shams.example.com peer lifecycle chaincode approveformyorg -o orderer.example.com:7050 --channelID ${CHANNEL_NAME} --name ${CC_NAME} --version ${CC_VERSION} --sequence ${CC_SEQUENCE} --package-id "$PKG_ID" --tls --cafile /opt/gopath/crypto/orderer/tlsca/tlsca.example.com-cert.pem
docker exec peer0.rebar.example.com peer lifecycle chaincode approveformyorg -o orderer.example.com:7050 --channelID ${CHANNEL_NAME} --name ${CC_NAME} --version ${CC_VERSION} --sequence ${CC_SEQUENCE} --package-id "$PKG_ID" --tls --cafile /opt/gopath/crypto/orderer/tlsca/tlsca.example.com-cert.pem

# Commit
docker exec peer0.shams.example.com peer lifecycle chaincode commit -o orderer.example.com:7050 --channelID ${CHANNEL_NAME} --name ${CC_NAME} --version ${CC_VERSION} --sequence ${CC_SEQUENCE} --tls --cafile /opt/gopath/crypto/orderer/tlsca/tlsca.example.com-cert.pem --peerAddresses peer0.shams.example.com:7051 --peerAddresses peer0.rebar.example.com:9051
