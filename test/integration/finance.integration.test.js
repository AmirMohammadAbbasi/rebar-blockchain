"use strict";
const chai = require("chai");
const expect = chai.expect;
const { connectAs } = require("./testUtils");

const { ensureAllTestIdentities } = require("./testUtils");

before(async () => {
  await ensureAllTestIdentities();
});

describe("Integration - FinanceContract", function () {
  this.timeout(20000);

  it("should create sales order and hash invoice", async () => {
    const gateway = await connectAs("FinanceUser");
    const network = await gateway.getNetwork("rebar-channel");
    const contract = network.getContract("rebarcc", "FinanceContract");

    const order = {
      orderNo: "SO_INT_001",
      customer: "CustA",
      invoice: { amount: 9000 },
    };
    const res = await contract.submitTransaction(
      "createSalesOrder",
      JSON.stringify(order)
    );

    const parsed = JSON.parse(res.toString());
    expect(parsed.invoiceHash).to.be.a("string");

    await gateway.disconnect();
  });

  it("should update payment status", async () => {
    const gateway = await connectAs("FinanceUser");
    const network = await gateway.getNetwork("rebar-channel");
    const contract = network.getContract("rebarcc", "FinanceContract");

    const res = await contract.submitTransaction(
      "updatePaymentStatus",
      "ORDER_SO_INT_001",
      "Paid"
    );

    const parsed = JSON.parse(res.toString());
    expect(parsed.paymentStatus).to.equal("Paid");

    await gateway.disconnect();
  });
});
