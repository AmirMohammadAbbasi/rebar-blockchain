"use strict";
const chai = require("chai");
const expect = chai.expect;
const { connectAs } = require("./testUtils");

const { ensureAllTestIdentities } = require("./testUtils");

before(async () => {
  await ensureAllTestIdentities();
});

describe("Integration - LifecycleContract", function () {
  this.timeout(20000);

  it("should track lifecycle for an asset", async () => {
    const gateway = await connectAs("LifecycleUser");
    const network = await gateway.getNetwork("rebar-channel");
    const contract = network.getContract("rebarcc", "LifecycleContract");

    const res = await contract.evaluateTransaction(
      "getProductLifecycle",
      "S_INT_001"
    );
    const parsed = JSON.parse(res.toString());
    expect(parsed).to.be.an("array");

    await gateway.disconnect();
  });
});
