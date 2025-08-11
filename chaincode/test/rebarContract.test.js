"use strict";
const chai = require("chai");
const expect = chai.expect;
const { ChaincodeMockStub } = require("fabric-shim");
const RebarContract = require("../chaincode/lib/rebarContract");

describe("RebarContract", () => {
  let contract, stub;

  beforeEach(() => {
    contract = new RebarContract();
    stub = new ChaincodeMockStub("RebarStub", contract);
  });

  it("should produce rebar from existing shams", async () => {
    // Preload shams in state
    await stub.putState("SHAMS_001", Buffer.from(JSON.stringify({})));
    const rebar = { batchNo: "R001", sourceShamsBatch: "001" };
    const proc = { furnace: "F1" };
    const res = await contract.produceRebarFromShams(
      stub,
      JSON.stringify(rebar),
      JSON.stringify(proc)
    );
    expect(res.processParams.furnace).to.equal("F1");
  });

  it("should fail if shams missing", async () => {
    try {
      await contract.produceRebarFromShams(
        stub,
        '{"batchNo":"R002","sourceShamsBatch":"XYZ"}',
        "{}"
      );
    } catch (err) {
      expect(err.message).to.match(/not found/);
    }
  });

  it("should add quality certificate", async () => {
    await stub.putState("REBAR_R001", Buffer.from(JSON.stringify({})));
    const res = await contract.addQualityCertificate(
      stub,
      "REBAR_R001",
      "hash123"
    );
    expect(res.qualityCertificates).to.have.lengthOf(1);
  });

  it("should record transport", async () => {
    const res = await contract.recordTransport(stub, '{"packageId":"PKG1"}');
    expect(res.docType).to.equal("transport");
  });
});
