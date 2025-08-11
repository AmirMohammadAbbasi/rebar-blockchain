#!/bin/bash

# ==== Channel & Chaincode Config ====
export CHANNEL_NAME=mychannel
export CC_NAME=rebarcc
export CC_VERSION=1.0
export CC_SEQUENCE=1

# مسیر chaincode داخل کانتینرهای peer
export CC_SRC_PATH=/opt/gopath/src/github.com/chaincode

# ==== Fabric CLI Tool Image ====
export TOOLS_IMG=hyperledger/fabric-tools:2.5

# پیکربندی configtxgen و cryptogen درون کانتینر
export FABRIC_CFG_PATH=/opt/gopath/config

# فایل‌های TLS CA درون کانتینر - Adjust اگر مسیر متفاوت بود
export ORDERER_CA=/var/hyperledger/tls/ca.crt
export PEER0_SHAMS_CA=/var/hyperledger/tls/ca.crt
export PEER0_REBAR_CA=/var/hyperledger/tls/ca.crt
