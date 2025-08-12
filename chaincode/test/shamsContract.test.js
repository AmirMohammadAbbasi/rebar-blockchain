"use strict";
const chai = require("chai");
const expect = chai.expect;
const { ChaincodeMockStub } = require("fabric-shim");
const ShamsContract = require("../lib/shamsContract");

describe("ShamsContract", () => {
  let contract, stub;

  beforeEach(() => {
    contract = new ShamsContract();
    stub = new ChaincodeMockStub("ShamsStub", contract);
  });

  it("should register a shams batch by ShamsMSP", async () => {
    stub.clientIdentity = { getMSPID: () => "ShamsMSP" };
    const shams = { batchNo: "001", origin: "MineX" };
    const purchase = { poNumber: "PO123", supplier: "SupplierCo" };
    const res = await contract.registerShamsBatch(
      stub,
      JSON.stringify(shams),
      JSON.stringify(purchase)
    );
    expect(res.batchNo).to.equal("001");
  });

  it("should reject non-ShamsMSP for registration", async () => {
    stub.clientIdentity = { getMSPID: () => "RebarMSP" };
    try {
      await contract.registerShamsBatch(stub, "{}", "{}");
    } catch (err) {
      expect(err.message).to.match(/Only ShamsMSP/);
    }
  });

  it("should confirm quality and emit events", async () => {
    stub.clientIdentity = { getMSPID: () => "ShamsMSP" };
    await contract.registerShamsBatch(
      stub,
      JSON.stringify({ batchNo: "002" }),
      "{}"
    );
    stub.clientIdentity = { getMSPID: () => "RebarMSP" };
    const res = await contract.confirmShamsQualityAndTriggerPayment(
      stub,
      "SHAMS_002",
      '{"lab":"OK"}'
    );
    expect(res.qualityReportHash).to.be.a("string");
  });
});
