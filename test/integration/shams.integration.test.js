"use strict";

const { connectAs } = require("./testUtils");
const { expect } = require("chai");

describe("Shams Contract Integration Tests", function () {
  this.timeout(30000);

  let gateway;
  let contract;
  let network;

  before(async function () {
    try {
      console.log("🔗 Connecting to network...");
      gateway = await connectAs("Admin", "Shams");
      network = await gateway.getNetwork("testchannel");
      contract = network.getContract("shams");
      console.log("✅ Connected to network and contract");
    } catch (error) {
      console.error("❌ Setup failed:", error);
      throw error;
    }
  });

  after(async function () {
    if (gateway) {
      gateway.disconnect();
      console.log("🔌 Disconnected from gateway");
    }
  });

  describe("Shams Creation", function () {
    it("should create a new shams successfully", async function () {
      const shamsId = `SHAMS_${Date.now()}`;
      const shamsData = {
        type: "IRON_ORE",
        grade: "A",
        weight: "1000",
        source: "Mine_A",
        certifications: ["ISO_9001", "QUALITY_CERT_001"],
      };

      const result = await contract.submitTransaction(
        "CreateShams",
        shamsId,
        shamsData.type,
        shamsData.grade,
        shamsData.weight,
        shamsData.source,
        JSON.stringify(shamsData.certifications)
      );

      console.log("✅ Shams created:", result.toString());
      expect(result.toString()).to.not.be.empty;
    });

    it("should query the created shams", async function () {
      const shamsId = `SHAMS_QUERY_${Date.now()}`;

      // ابتدا یک شمش ایجاد کنیم
      await contract.submitTransaction(
        "CreateShams",
        shamsId,
        "STEEL",
        "B",
        "800",
        "Mine_B",
        JSON.stringify(["CERT_002"])
      );

      // سپس آن را query کنیم
      const result = await contract.evaluateTransaction("QueryShams", shamsId);
      const shamsData = JSON.parse(result.toString());

      expect(shamsData).to.have.property("id", shamsId);
      expect(shamsData).to.have.property("type", "STEEL");
      expect(shamsData).to.have.property("grade", "B");
      expect(shamsData).to.have.property("weight", "800");
    });
  });

  describe("Bundle Management", function () {
    it("should create a milbard bundle", async function () {
      const bundleId = `BUNDLE_${Date.now()}`;
      const shamsIds = [`SHAMS_1_${Date.now()}`, `SHAMS_2_${Date.now()}`];

      // ابتدا شمش‌ها را ایجاد کنیم
      for (let shamsId of shamsIds) {
        await contract.submitTransaction(
          "CreateShams",
          shamsId,
          "IRON_ORE",
          "A",
          "500",
          "Mine_C",
          JSON.stringify(["CERT_003"])
        );
      }

      // سپس bundle ایجاد کنیم
      const result = await contract.submitTransaction(
        "CreateMilbardBundle",
        bundleId,
        JSON.stringify(shamsIds),
        "2000"
      );

      console.log("✅ Bundle created:", result.toString());
      expect(result.toString()).to.not.be.empty;
    });

    it("should update bundle status", async function () {
      const bundleId = `BUNDLE_STATUS_${Date.now()}`;
      const shamsIds = [`SHAMS_STATUS_${Date.now()}`];

      // شمش و bundle ایجاد کنیم
      await contract.submitTransaction(
        "CreateShams",
        shamsIds[0],
        "STEEL",
        "A",
        "1000",
        "Mine_D",
        JSON.stringify(["CERT_004"])
      );

      await contract.submitTransaction(
        "CreateMilbardBundle",
        bundleId,
        JSON.stringify(shamsIds),
        "1000"
      );

      // وضعیت را به‌روزرسانی کنیم
      const result = await contract.submitTransaction(
        "UpdateBundleStatus",
        bundleId,
        "IN_TRANSIT"
      );

      console.log("✅ Bundle status updated:", result.toString());
      expect(result.toString()).to.not.be.empty;
    });
  });

  describe("Query Operations", function () {
    it("should query all bundles", async function () {
      const result = await contract.evaluateTransaction("QueryAllBundles");
      const bundles = JSON.parse(result.toString());

      expect(bundles).to.be.an("array");
      console.log(`✅ Found ${bundles.length} bundles`);
    });

    it("should query bundle history", async function () {
      const bundleId = `BUNDLE_HISTORY_${Date.now()}`;
      const shamsIds = [`SHAMS_HISTORY_${Date.now()}`];

      // شمش و bundle ایجاد کنیم
      await contract.submitTransaction(
        "CreateShams",
        shamsIds[0],
        "IRON_ORE",
        "B",
        "750",
        "Mine_E",
        JSON.stringify(["CERT_005"])
      );

      await contract.submitTransaction(
        "CreateMilbardBundle",
        bundleId,
        JSON.stringify(shamsIds),
        "750"
      );

      // چند بار وضعیت را تغییر دهیم
      await contract.submitTransaction(
        "UpdateBundleStatus",
        bundleId,
        "PREPARED"
      );
      await contract.submitTransaction(
        "UpdateBundleStatus",
        bundleId,
        "IN_TRANSIT"
      );

      // تاریخچه را query کنیم
      const result = await contract.evaluateTransaction(
        "QueryBundleHistory",
        bundleId
      );
      const history = JSON.parse(result.toString());

      expect(history).to.be.an("array");
      expect(history.length).to.be.greaterThan(0);
      console.log(`✅ Bundle history has ${history.length} entries`);
    });
  });
});
