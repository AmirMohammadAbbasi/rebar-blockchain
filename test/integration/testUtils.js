"use strict";

const { Wallets } = require("fabric-network");
const FabricCAServices = require("fabric-ca-client");
const path = require("path");

const orgs = [
  {
    name: "Shams",
    mspId: "ShamsMSP",
    caURL: "http://ca.shams.example.com:7054",
    adminUserId: "admin",
    adminPassword: "adminpw",
  },
  {
    name: "Rebar",
    mspId: "RebarMSP",
    caURL: "http://ca.rebar.example.com:8054",
    adminUserId: "admin",
    adminPassword: "adminpw",
  },
  {
    name: "Finance",
    mspId: "FinanceMSP",
    caURL: "http://ca.finance.example.com:9054",
    adminUserId: "admin",
    adminPassword: "adminpw",
  },
  {
    name: "Lifecycle",
    mspId: "LifecycleMSP",
    caURL: "http://ca.lifecycle.example.com:10054",
    adminUserId: "admin",
    adminPassword: "adminpw",
  },
];

async function enrollAdmin(ca, wallet, mspId, adminUserId, adminPassword) {
  const identity = await wallet.get(adminUserId);
  if (identity) {
    console.log(`Admin identity for ${mspId} already exists in wallet`);
    return;
  }
  const enrollment = await ca.enroll({
    enrollmentID: adminUserId,
    enrollmentSecret: adminPassword,
  });
  const x509Identity = {
    credentials: {
      certificate: enrollment.certificate,
      privateKey: enrollment.key.toBytes(),
    },
    mspId,
    type: "X.509",
  };
  await wallet.put(adminUserId, x509Identity);
  console.log(`✅ Admin identity for ${mspId} enrolled and imported to wallet`);
}

async function registerAndEnrollUser(ca, wallet, mspId, userId) {
  const userIdentity = await wallet.get(userId);
  if (userIdentity) {
    console.log(`User identity ${userId} already exists in wallet`);
    return;
  }

  const adminIdentity = await wallet.get("admin");
  if (!adminIdentity) {
    throw new Error(`Admin identity not found in wallet for MSP ${mspId}`);
  }

  const provider = wallet.getProviderRegistry().getProvider(adminIdentity.type);
  const adminUser = await provider.getUserContext(adminIdentity, "admin");

  // affiliation حذف شده
  const secret = await ca.register(
    { enrollmentID: userId, role: "client" },
    adminUser
  );
  const enrollment = await ca.enroll({
    enrollmentID: userId,
    enrollmentSecret: secret,
  });
  const x509Identity = {
    credentials: {
      certificate: enrollment.certificate,
      privateKey: enrollment.key.toBytes(),
    },
    mspId,
    type: "X.509",
  };
  await wallet.put(userId, x509Identity);
  console.log(`✅ User identity ${userId} enrolled and imported to wallet`);
}

async function ensureAllTestIdentities() {
  const walletPath = path.join(__dirname, "wallet");
  const wallet = await Wallets.newFileSystemWallet(walletPath);

  for (let org of orgs) {
    const ca = new FabricCAServices(org.caURL, {
      trustedRoots: [],
      verify: false,
    });

    await enrollAdmin(
      ca,
      wallet,
      org.mspId,
      org.adminUserId,
      org.adminPassword
    );

    // affiliation حذف شده
    await registerAndEnrollUser(ca, wallet, org.mspId, `${org.name}User`);
  }
}

module.exports = {
  ensureAllTestIdentities,
};
