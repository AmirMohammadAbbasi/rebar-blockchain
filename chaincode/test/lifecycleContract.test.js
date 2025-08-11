"use strict";
const chai = require("chai");
const expect = chai.expect;
const { ChaincodeMockStub } = require("fabric-shim");
const LifecycleContract = require("../chaincode/lib/lifecycleContract");

describe("LifecycleContract", () => {
  let contract, stub;

  beforeEach(() => {
    contract = new LifecycleContract();
    stub = new ChaincodeMockStub("LifecycleStub", contract);
  });

  it("should return empty history if no tx", async () => {
    const res = await contract.getProductLifecycle(stub, "NON_EXISTENT");
    expect(res).to.be.an("array").that.is.empty;
  });

  it("should track history after a putState", async () => {
    await stub.putState("PROD1", Buffer.from("test"));
    const hist = await contract.getProductLifecycle(stub, "PROD1");
    expect(hist).to.be.an("array");
  });
});
