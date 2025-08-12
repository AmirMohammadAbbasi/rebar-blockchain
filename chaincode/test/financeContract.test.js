"use strict";
const chai = require("chai");
const expect = chai.expect;
const { ChaincodeMockStub } = require("fabric-shim");
const FinanceContract = require("../lib/financeContract");

describe("FinanceContract", () => {
  let contract, stub;

  beforeEach(() => {
    contract = new FinanceContract();
    stub = new ChaincodeMockStub("FinanceStub", contract);
  });

  it("should create sales order and hash invoice", async () => {
    const order = {
      orderNo: "SO1",
      customer: "Cust1",
      invoice: { amount: 1000 },
    };
    const res = await contract.createSalesOrder(stub, JSON.stringify(order));
    expect(res.invoiceHash).to.be.a("string");
    expect(res).to.not.have.property("invoice");
  });

  it("should update payment status", async () => {
    await stub.putState("ORDER_SO1", Buffer.from(JSON.stringify({})));
    const res = await contract.updatePaymentStatus(stub, "ORDER_SO1", "Paid");
    expect(res.paymentStatus).to.equal("Paid");
  });
});
