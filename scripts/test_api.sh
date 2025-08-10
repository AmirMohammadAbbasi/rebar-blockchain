#!/bin/bash
set -e
source ./scripts/env.sh

echo "📤 Invoking initLedger on ShamsContract..."
docker exec peer0.shams.example.com peer chaincode invoke -o orderer.example.com:7050 --channelID $CHANNEL_NAME --name $CC_NAME -c '{"function":"ShamsContract:initLedger","Args":[]}' --waitForEvent

echo "📥 Querying ledger..."
docker exec peer0.shams.example.com peer chaincode query --channelID $CHANNEL_NAME --name $CC_NAME -c '{"Args":["ShamsContract:getAll"]}'
