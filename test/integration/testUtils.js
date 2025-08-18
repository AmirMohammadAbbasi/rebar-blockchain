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

  // تعیین مسیر user مناسب
  let actualUserId, actualOrgName, actualMspId, actualCryptoPath;

  if (
    userId === "CustomerUser" ||
    userId === "ShamsUser" ||
    userId === "LifecycleUser"
  ) {
    actualUserId = "Admin";
    actualOrgName = "shams";
    actualMspId = "ShamsMSP";
    actualCryptoPath =
      "/etc/hyperledger/crypto-config/peerOrganizations/shams.example.com";
  } else if (userId === "FinanceUser" || userId === "RebarUser") {
    actualUserId = "Admin";
    actualOrgName = "rebar";
    actualMspId = "RebarMSP";
    actualCryptoPath =
      "/etc/hyperledger/crypto-config/peerOrganizations/rebar.example.com";
  } else {
    actualUserId = userId;
    actualOrgName = orgName.toLowerCase();
    actualMspId = mspId;
    actualCryptoPath = cryptoPath;
  }

  const userPath = path.join(
    actualCryptoPath,
    "users",
    `${actualUserId}@${actualOrgName}.example.com`
  );

  console.log(
    `🔍 Loading identity ${userId} (actual: ${actualUserId}) for ${actualMspId}`
  );
  console.log(`📁 Looking for crypto materials at: ${userPath}`);

  // بررسی وجود مسیر
  if (!fs.existsSync(userPath)) {
    console.log(`❌ User path does not exist: ${userPath}`);

    // نمایش مسیرهای موجود برای دیباگ
    const usersDir = path.join(actualCryptoPath, "users");
    if (fs.existsSync(usersDir)) {
      console.log(`Available users:`, fs.readdirSync(usersDir));
    }

    throw new Error(`User path not found: ${userPath}`);
  }

  const certPath = path.join(userPath, "msp", "signcerts");
  const keyPath = path.join(userPath, "msp", "keystore");

  if (!fs.existsSync(certPath) || !fs.existsSync(keyPath)) {
    throw new Error(
      `Crypto materials not found for ${actualUserId}@${actualOrgName} at ${userPath}`
    );
  }

  const certFiles = fs.readdirSync(certPath);
  const keyFiles = fs.readdirSync(keyPath);

  if (certFiles.length === 0 || keyFiles.length === 0) {
    throw new Error(
      `No certificate or key files found for ${actualUserId}@${actualOrgName}`
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
    mspId: actualMspId,
    type: "X.509",
  };

  await wallet.put(userId, x509Identity);
  console.log(`✅ Identity ${userId} for ${actualMspId} loaded successfully`);
}

async function ensureAllTestIdentities() {
  const walletPath = path.join(__dirname, "wallet");
  const wallet = await Wallets.newFileSystemWallet(walletPath);

  // Load Admin identities for both orgs
  for (let org of orgs) {
    await loadIdentityFromCrypto(
      wallet,
      org.mspId,
      org.name,
      org.cryptoPath,
      "Admin"
    );
  }

  // Load specific test users
  const testUsers = [
    "CustomerUser",
    "ShamsUser",
    "LifecycleUser",
    "FinanceUser",
    "RebarUser",
  ];

  for (let userId of testUsers) {
    await loadIdentityFromCrypto(wallet, "AUTO", "AUTO", "AUTO", userId);
  }
}

async function connectAs(identityLabel, orgName = "Shams") {
  await ensureAllTestIdentities();

  const walletPath = path.join(__dirname, "wallet");
  const wallet = await Wallets.newFileSystemWallet(walletPath);

  const ccpPath = path.resolve(__dirname, "connections", "connection.json");

  if (!fs.existsSync(ccpPath)) {
    throw new Error(`Connection profile not found at: ${ccpPath}`);
  }

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
