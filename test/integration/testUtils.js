"use strict";

const path = require("path");
const { Gateway, Wallets } = require("fabric-network");
const fs = require("fs");

const orgs = [
  {
    name: "Shams",
    mspId: "ShamsMSP",
    cryptoPath:
      "/etc/hyperledger/crypto-config/peerOrganizations/shams.example.com",
  },
  {
    name: "Rebar",
    mspId: "RebarMSP",
    cryptoPath:
      "/etc/hyperledger/crypto-config/peerOrganizations/rebar.example.com",
  },
];

async function loadIdentityFromCrypto(
  wallet,
  mspId,
  orgName,
  cryptoPath,
  userId = "Admin"
) {
  const identity = await wallet.get(userId);
  if (identity) {
    console.log(`Identity ${userId} for ${mspId} already exists in wallet`);
    return;
  }

  // برای RebarUser از Admin credentials استفاده می‌کنیم
  const actualUserId = userId === "RebarUser" ? "Admin" : userId;

  const userPath = path.join(
    cryptoPath,
    "users",
    `${actualUserId}@${orgName.toLowerCase()}.example.com`
  );
  const certPath = path.join(userPath, "msp", "signcerts");
  const keyPath = path.join(userPath, "msp", "keystore");

  if (!fs.existsSync(certPath) || !fs.existsSync(keyPath)) {
    throw new Error(
      `Crypto materials not found for ${actualUserId}@${orgName} at ${userPath}`
    );
  }

  const certFiles = fs.readdirSync(certPath);
  const keyFiles = fs.readdirSync(keyPath);

  if (certFiles.length === 0 || keyFiles.length === 0) {
    throw new Error(
      `No certificate or key files found for ${actualUserId}@${orgName}`
    );
  }

  const certificate = fs.readFileSync(
    path.join(certPath, certFiles[0]),
    "utf8"
  );
  const privateKey = fs.readFileSync(path.join(keyPath, keyFiles[0]), "utf8");

  const x509Identity = {
    credentials: {
      certificate,
      privateKey,
    },
    mspId,
    type: "X.509",
  };

  await wallet.put(userId, x509Identity);
  console.log(
    `✅ Identity ${userId} for ${mspId} loaded from crypto materials`
  );
}

async function ensureAllTestIdentities() {
  const walletPath = path.join(__dirname, "wallet");
  const wallet = await Wallets.newFileSystemWallet(walletPath);

  for (let org of orgs) {
    // Load Admin
    await loadIdentityFromCrypto(
      wallet,
      org.mspId,
      org.name,
      org.cryptoPath,
      "Admin"
    );

    // Load RebarUser برای Rebar org
    if (org.name === "Rebar") {
      await loadIdentityFromCrypto(
        wallet,
        org.mspId,
        org.name,
        org.cryptoPath,
        "RebarUser"
      );
    }
  }
}

async function connectAs(identityLabel, orgName = "Shams") {
  await ensureAllTestIdentities();

  const walletPath = path.join(__dirname, "wallet");
  const wallet = await Wallets.newFileSystemWallet(walletPath);

  const ccpPath = path.resolve(__dirname, "connections", "connection.json");
  const ccp = JSON.parse(fs.readFileSync(ccpPath, "utf8"));

  const gateway = new Gateway();
  await gateway.connect(ccp, {
    wallet,
    identity: identityLabel,
    discovery: { enabled: false, asLocalhost: false },
  });
  return gateway;
}

module.exports = {
  ensureAllTestIdentities,
  connectAs,
};
