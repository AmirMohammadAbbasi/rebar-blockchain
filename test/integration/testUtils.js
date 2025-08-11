"use strict";

const fs = require("fs");
const path = require("path");
const { Wallets } = require("fabric-network");

const baseCryptoPath = "/workspace/config/crypto-config"; // مسیر mount شده در test-runner

async function ensureIdentity(label, mspId, certPath, keyPath) {
  const walletPath = path.resolve(__dirname, "wallet");
  const wallet = await Wallets.newFileSystemWallet(walletPath);

  const exists = await wallet.get(label);
  if (exists) {
    return;
  }

  const cert = fs.readFileSync(certPath, "utf8");
  const key = fs.readFileSync(keyPath, "utf8");

  await wallet.put(label, {
    credentials: { certificate: cert, privateKey: key },
    mspId,
    type: "X.509",
  });
  console.log(`✔ Added missing identity: ${label}`);
}

async function ensureAllTestIdentities() {
  await ensureIdentity(
    "ShamsUser",
    "Org1MSP",
    `${baseCryptoPath}/peerOrganizations/org1.example.com/users/User1@org1.example.com/msp/signcerts/User1@org1.example.com-cert.pem`,
    `${baseCryptoPath}/peerOrganizations/org1.example.com/users/User1@org1.example.com/msp/keystore/priv_sk`
  );
  await ensureIdentity(
    "RebarUser",
    "Org2MSP",
    `${baseCryptoPath}/peerOrganizations/org2.example.com/users/User1@org2.example.com/msp/signcerts/User1@org2.example.com-cert.pem`,
    `${baseCryptoPath}/peerOrganizations/org2.example.com/users/User1@org2.example.com/msp/keystore/priv_sk`
  );
  await ensureIdentity(
    "FinanceUser",
    "Org3MSP",
    `${baseCryptoPath}/peerOrganizations/org3.example.com/users/User1@org3.example.com/msp/signcerts/User1@org3.example.com-cert.pem`,
    `${baseCryptoPath}/peerOrganizations/org3.example.com/users/User1@org3.example.com/msp/keystore/priv_sk`
  );
  await ensureIdentity(
    "LifecycleUser",
    "Org4MSP",
    `${baseCryptoPath}/peerOrganizations/org4.example.com/users/User1@org4.example.com/msp/signcerts/User1@org4.example.com-cert.pem`,
    `${baseCryptoPath}/peerOrganizations/org4.example.com/users/User1@org4.example.com/msp/keystore/priv_sk`
  );
}

module.exports = { ensureAllTestIdentities };
