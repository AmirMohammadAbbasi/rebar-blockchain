"use strict";
const chai = require("chai");
const expect = chai.expect;
const { connectAs } = require("./testUtils");

const { ensureAllTestIdentities } = require("./testUtils");

before(async () => {
  await ensureAllTestIdentities();
});

describe("Integration - RebarContract", function () {
  this.timeout(20000);

  it("should produce rebar from existing shams batch", async () => {
    const gateway = await connectAs("RebarUser");
    const network = await gateway.getNetwork(
      process.env.CHANNEL_NAME || "testchannel"
    );
    const contract = network.getContract("rebarcc", "RebarContract");

    const rebar = { batchNo: "RB_INT_001", sourceShamsBatch: "S_INT_001" };
    const result = await contract.submitTransaction(
      "produceRebarFromShams",
      JSON.stringify(rebar),
      JSON.stringify({ furnace: "FM-1" })
    );

    const parsed = JSON.parse(result.toString());
    expect(parsed.batchNo).to.equal("RB_INT_001");
    await gateway.disconnect();
  });

  it("should fail for missing shams batch", async () => {
    const gateway = await connectAs("RebarUser");
    const network = await gateway.getNetwork(
      process.env.CHANNEL_NAME || "testchannel"
    );
    const contract = network.getContract("rebarcc", "RebarContract");

    try {
      await contract.submitTransaction(
        "produceRebarFromShams",
        '{"batchNo":"RB_ERR","sourceShamsBatch":"NO_SUCH"}',
        "{}"
      );
      throw new Error("Expected missing shams error");
    } catch (err) {
      expect(err.message).to.match(/not found/i);
    }
    await gateway.disconnect();
  });
});
