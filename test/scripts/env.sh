#!/bin/bash

# Channel configuration
export CHANNEL_NAME="testchannel"

# Chaincode configuration
export CC_NAME="rebarcc"
export CC_VERSION="1.0"
export CC_SEQUENCE="1"
export CC_SRC_PATH="/opt/gopath/src/github.com/chaincode"

# Orderer configuration
export ORDERER_ENDPOINT="test-orderer.example.com:7150"

# Organization MSPs
export SHAMS_MSP_ID="ShamsMSP"
export REBAR_MSP_ID="RebarMSP"
export ORDERER_MSP_ID="OrdererMSP"

# Peer addresses
export SHAMS_PEER="test-peer0.shams.example.com:7151"
export REBAR_PEER="test-peer0.rebar.example.com:9151"
