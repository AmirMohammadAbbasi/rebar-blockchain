"use strict";
const { Contract } = require("fabric-contract-api");

class RebarContract extends Contract {
  constructor() {
    super("rebar.rebar.contract");
  }

  async produceRebarFromShams(ctx, rebarJson, processParamsJson) {
    const data = JSON.parse(rebarJson);
    const id = `REBAR_${data.batchNo}`;

    if (
      !(await ctx.stub
        .getState(`SHAMS_${data.sourceShamsBatch}`)
        .then((b) => b && b.length > 0))
    )
      throw new Error(`Shams batch ${data.sourceShamsBatch} not found`);

    data.docType = "rebar";
    data.processParams = JSON.parse(processParamsJson);
    data.producedAt = new Date().toISOString();
    await ctx.stub.putState(id, Buffer.from(JSON.stringify(data)));
    await ctx.stub.setEvent(
      "RebarProduced",
      Buffer.from(JSON.stringify({ id }))
    );
    return data;
  }

  async addQualityCertificate(ctx, rebarId, certificateHash) {
    const buf = await ctx.stub.getState(rebarId);
    if (!buf || buf.length === 0) throw new Error(`Rebar ${rebarId} not found`);
    const rec = JSON.parse(buf.toString());
    rec.qualityCertificates = rec.qualityCertificates || [];
    rec.qualityCertificates.push({
      hash: certificateHash,
      addedAt: new Date().toISOString(),
    });
    await ctx.stub.putState(rebarId, Buffer.from(JSON.stringify(rec)));
    return rec;
  }

  async packageRebar(ctx, packageJson) {
    const pkg = JSON.parse(packageJson);
    const id = `PKG_${pkg.packageNo}`;
    pkg.docType = "rebarPackage";
    pkg.packagedAt = new Date().toISOString();
    await ctx.stub.putState(id, Buffer.from(JSON.stringify(pkg)));
    await ctx.stub.setEvent(
      "RebarPackaged",
      Buffer.from(JSON.stringify({ id }))
    );
    return pkg;
  }

  async recordTransport(ctx, transportJson) {
    const data = JSON.parse(transportJson);
    const id = `TRANS_${data.packageId}_${Date.now()}`;
    data.docType = "transport";
    data.recordedAt = new Date().toISOString();
    await ctx.stub.putState(id, Buffer.from(JSON.stringify(data)));
    await ctx.stub.setEvent(
      "TransportRecorded",
      Buffer.from(JSON.stringify({ id }))
    );
    return data;
  }

  async confirmDelivery(ctx, packageId, receiverSignature) {
    const id = `DELIV_${packageId}`;
    const deliveryConfirmation = {
      docType: "deliveryProof",
      packageId,
      signature: receiverSignature,
      confirmedAt: new Date().toISOString(),
    };
    await ctx.stub.putState(
      id,
      Buffer.from(JSON.stringify(deliveryConfirmation))
    );
    await ctx.stub.setEvent(
      "DeliveryConfirmed",
      Buffer.from(JSON.stringify({ packageId }))
    );

    // شبیه‌سازی قرارداد پرداخت حمل و نقل
    await ctx.stub.setEvent(
      "TransportPaymentTriggered",
      Buffer.from(
        JSON.stringify({
          packageId,
          action: "ReleaseTransportPayment",
        })
      )
    );
    return deliveryConfirmation;
  }
}

module.exports = RebarContract;
