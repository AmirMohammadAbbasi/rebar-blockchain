"use strict";
const chai = require("chai");
const expect = chai.expect;
const { connectAs } = require("./testUtils");

const { ensureAllTestIdentities } = require("./testUtils");

before(async () => {
  await ensureAllTestIdentities();
});

describe("Integration - ShamsContract", function () {
  this.timeout(20000);

  it("should register a shams batch (success)", async () => {
    const gateway = await connectAs("ShamsUser");
    const network = await gateway.getNetwork(
      process.env.CHANNEL_NAME || "testchannel"
    );
    const contract = network.getContract("rebarcc", "ShamsContract");

    const shams = {
      batchNo: "S_INT_001",
      origin: "MineA",
      specs: { grade: "A" },
    };
    const purchase = { po: "PO_INT_001" };
    const result = await contract.submitTransaction(
      "registerShamsBatch",
      JSON.stringify(shams),
      JSON.stringify(purchase)
    );

    const parsed = JSON.parse(result.toString());
    expect(parsed.batchNo).to.equal("S_INT_001");
    await gateway.disconnect();
  });

  it("should fail for non-ShamsMSP user", async () => {
    const gateway = await connectAs("RebarUser");
    const network = await gateway.getNetwork(
      process.env.CHANNEL_NAME || "testchannel"
    );
    const contract = network.getContract("rebarcc", "ShamsContract");

    try {
      await contract.submitTransaction("registerShamsBatch", "{}", "{}");
      throw new Error("Expected MSP error");
    } catch (err) {
      expect(err.message).to.match(/Only ShamsMSP/);
    }
    await gateway.disconnect();
  });
});
