"use strict";
const { Contract } = require("fabric-contract-api");
const crypto = require("crypto");

class ShamsContract extends Contract {
  constructor() {
    super("rebar.shams.contract");
  }

  _getClientOrgId(ctx) {
    return ctx.clientIdentity.getMSPID();
  }

  _hashSensitive(data) {
    return crypto
      .createHash("sha256")
      .update(JSON.stringify(data))
      .digest("hex");
  }

  async registerShamsBatch(ctx, shamsJson, purchaseDetailsJson) {
    const callerMsp = this._getClientOrgId(ctx);
    if (callerMsp !== "ShamsMSP") {
      throw new Error("Only ShamsMSP can register raw shams batches");
    }

    const shams = JSON.parse(shamsJson);
    const id = `SHAMS_${shams.batchNo}`;

    if (await ctx.stub.getState(id).then((b) => b && b.length > 0)) {
      throw new Error(`Shams batch ${shams.batchNo} already exists`);
    }

    const purchaseDetails = JSON.parse(purchaseDetailsJson);
    const shamsRecord = {
      docType: "shams",
      ...shams,
      purchaseDetailsHash: this._hashSensitive(purchaseDetails),
      registeredBy: callerMsp,
      registeredAt: new Date().toISOString(),
    };

    await ctx.stub.putState(id, Buffer.from(JSON.stringify(shamsRecord)));
    await ctx.stub.setEvent(
      "ShamsRegistered",
      Buffer.from(JSON.stringify({ id }))
    );
    return shamsRecord;
  }

  async confirmShamsQualityAndTriggerPayment(ctx, shamsId, qualityReportJson) {
    const callerMsp = this._getClientOrgId(ctx);
    if (callerMsp !== "ShamsMSP" && callerMsp !== "RebarMSP") {
      throw new Error("Not authorized to confirm quality");
    }

    const asset = await ctx.stub.getState(shamsId);
    if (!asset || asset.length === 0)
      throw new Error(`Shams ${shamsId} not found`);
    const record = JSON.parse(asset.toString());

    const qualityReport = JSON.parse(qualityReportJson);
    record.qualityReportHash = this._hashSensitive(qualityReport);
    record.qualityConfirmedAt = new Date().toISOString();
    await ctx.stub.putState(shamsId, Buffer.from(JSON.stringify(record)));

    await ctx.stub.setEvent(
      "QualityConfirmed",
      Buffer.from(JSON.stringify({ shamsId }))
    );

    // شبیه‌سازی قرارداد هوشمند پرداخت به تأمین‌کننده
    await ctx.stub.setEvent(
      "PaymentTriggered",
      Buffer.from(
        JSON.stringify({
          shamsId,
          action: "ReleasePaymentToSupplier",
        })
      )
    );

    return record;
  }
}

module.exports = ShamsContract;
