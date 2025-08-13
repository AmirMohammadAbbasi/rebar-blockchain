"use strict";
const { connectAs, ensureAllTestIdentities } = require("./testUtils");
const { expect } = require("chai");

describe("Integration - ComplaintContract Weighted Consensus", function () {
  this.timeout(30000);
  let netCustomer, netShams, netRebar, netTransport;
  let contractCustomer, contractShams, contractRebar, contractTransport;

  before(async () => {
    await ensureAllTestIdentities();

    const gwCustomer = await connectAs("CustomerUser");
    const gwShams = await connectAs("ShamsUser");
    const gwRebar = await connectAs("RebarUser");
    const gwTransport = await connectAs("LifecycleUser"); // برای TransportMSP

    netCustomer = await gwCustomer.getNetwork("testchannel");
    netShams = await gwShams.getNetwork("testchannel");
    netRebar = await gwRebar.getNetwork("testchannel");
    netTransport = await gwTransport.getNetwork("testchannel");

    contractCustomer = netCustomer.getContract(
      "rebarcc",
      "rebar.complaint.contract"
    );
    contractShams = netShams.getContract("rebarcc", "rebar.complaint.contract");
    contractRebar = netRebar.getContract("rebarcc", "rebar.complaint.contract");
    contractTransport = netTransport.getContract(
      "rebarcc",
      "rebar.complaint.contract"
    );
  });

  it("✅ ثبت شکایت موفق و دریافت آن", async () => {
    const res = await contractCustomer.submitTransaction(
      "registerComplaint",
      "BUNDLE_X1",
      "QualityIssue",
      "شکستن میلگردها",
      "Hash123"
    );
    const parsed = JSON.parse(res.toString());

    expect(parsed.status).to.equal("PendingVoting");

    const readRes = await contractCustomer.evaluateTransaction(
      "readComplaint",
      parsed.id
    );
    expect(JSON.parse(readRes.toString()).id).to.equal(parsed.id);
  });

  it("🚫 جلوگیری از ثبت شکایت توسط MSP غیر مجاز", async () => {
    try {
      await contractTransport.submitTransaction(
        "registerComplaint",
        "BUNDLE_X2",
        "DeliveryDelay",
        "تاخیر در ارسال",
        "Hash456"
      );
      throw new Error("Expected Unauthorized error");
    } catch (err) {
      expect(err.message).to.match(/Unauthorized/);
    }
  });

  it("✅ اجماع موفق با وزن کافی", async () => {
    const res = await contractCustomer.submitTransaction(
      "registerComplaint",
      "BUNDLE_X3",
      "WeightMismatch",
      "وزن کمتر",
      "Hash789"
    );
    const compId = JSON.parse(res.toString()).id;

    await contractShams.submitTransaction("voteOnComplaint", compId, "accept"); // 2 وزن
    await contractRebar.submitTransaction("voteOnComplaint", compId, "accept"); // 2 وزن

    const consensus = await contractCustomer.submitTransaction(
      "checkConsensus",
      compId,
      "4"
    );
    expect(JSON.parse(consensus.toString()).status).to.equal("Approved");
  });

  it("🚫 جلوگیری از رأی تکراری توسط یک MSP", async () => {
    const res = await contractCustomer.submitTransaction(
      "registerComplaint",
      "BUNDLE_X4",
      "BrokenPackaging",
      "بسته بندی آسیب دیده",
      "HashPKG"
    );
    const compId = JSON.parse(res.toString()).id;

    await contractShams.submitTransaction("voteOnComplaint", compId, "accept");
    try {
      await contractShams.submitTransaction(
        "voteOnComplaint",
        compId,
        "reject"
      );
      throw new Error("Expected duplicate vote error");
    } catch (err) {
      expect(err.message).to.match(/already voted/);
    }
  });

  it("❌ همه رأی بدهند ولی وزن کافی نباشد → Rejected", async () => {
    const res = await contractCustomer.submitTransaction(
      "registerComplaint",
      "BUNDLE_X5",
      "MinorScratch",
      "خراش جزیی",
      "HashSCR"
    );
    const compId = JSON.parse(res.toString()).id;

    await contractShams.submitTransaction("voteOnComplaint", compId, "accept"); // 2
    await contractRebar.submitTransaction("voteOnComplaint", compId, "reject"); // 0
    await contractTransport.submitTransaction(
      "voteOnComplaint",
      compId,
      "accept"
    ); // 1
    await contractCustomer.submitTransaction(
      "voteOnComplaint",
      compId,
      "accept"
    ); // 1

    const consensus = await contractCustomer.submitTransaction(
      "checkConsensus",
      compId,
      "5"
    ); // آستانه بیشتر از مجموع قبول‌ها
    expect(JSON.parse(consensus.toString()).status).to.equal("Rejected");
  });

  it("🚫 رأی توسط MSP غیر مجاز", async () => {
    // فرض می‌کنیم MSP Finance مجاز به رأی نیست
    const compRes = await contractCustomer.submitTransaction(
      "registerComplaint",
      "BUNDLE_X6",
      "NoSupportDocs",
      "فقدان مستندات",
      "HashDOC"
    );
    const compId = JSON.parse(compRes.toString()).id;

    try {
      const gwFinance = await connectAs("FinanceUser");
      const netFinance = await gwFinance.getNetwork("testchannel");
      const contractFinance = netFinance.getContract(
        "rebarcc",
        "rebar.complaint.contract"
      );

      await contractFinance.submitTransaction(
        "voteOnComplaint",
        compId,
        "accept"
      );
      throw new Error("Expected unauthorized vote error");
    } catch (err) {
      expect(err.message).to.match(/not authorized to vote/i);
    }
  });
});
