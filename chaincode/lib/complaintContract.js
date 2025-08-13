"use strict";
const { Contract } = require("fabric-contract-api");

class ComplaintContract extends Contract {
  constructor() {
    super("rebar.complaint.contract");
  }

  _getClientOrgId(ctx) {
    return ctx.clientIdentity.getMSPID();
  }

  async registerComplaint(ctx, targetId, type, description, evidenceHash) {
    const callerMsp = this._getClientOrgId(ctx);
    const allowed = ["CustomerMSP", "ShamsMSP", "RebarMSP", "TransportMSP"];
    if (!allowed.includes(callerMsp)) {
      throw new Error("Unauthorized to register complaint");
    }

    const id = `COMP_${Date.now()}`;
    const complaint = {
      docType: "complaint",
      id,
      targetId,
      type,
      description,
      evidenceHash,
      status: "PendingVoting",
      votes: [],
      createdBy: callerMsp,
      createdAt: new Date().toISOString(),
    };

    await ctx.stub.putState(id, Buffer.from(JSON.stringify(complaint)));
    await ctx.stub.setEvent(
      "ComplaintRegistered",
      Buffer.from(JSON.stringify({ id, targetId }))
    );

    return complaint;
  }

  async voteOnComplaint(ctx, complaintId, vote) {
    const callerMsp = this._getClientOrgId(ctx);
    const buf = await ctx.stub.getState(complaintId);
    if (!buf || buf.length === 0) {
      throw new Error(`Complaint ${complaintId} not found`);
    }

    const complaint = JSON.parse(buf.toString());
    if (complaint.status !== "PendingVoting") {
      throw new Error(`Voting closed for complaint ${complaintId}`);
    }

    // جلوگیری از رأی تکراری
    if (complaint.votes.some((v) => v.org === callerMsp)) {
      throw new Error(`Org ${callerMsp} already voted`);
    }

    const voteObj = {
      org: callerMsp,
      vote,
      at: new Date().toISOString(),
    };
    complaint.votes.push(voteObj);

    await ctx.stub.putState(
      complaintId,
      Buffer.from(JSON.stringify(complaint))
    );
    return complaint;
  }

  async checkConsensus(ctx, complaintId, requiredAccepts) {
    const buf = await ctx.stub.getState(complaintId);
    if (!buf || buf.length === 0) {
      throw new Error(`Complaint ${complaintId} not found`);
    }

    const complaint = JSON.parse(buf.toString());
    if (complaint.status !== "PendingVoting") {
      return complaint; // No change
    }

    const accepts = complaint.votes.filter((v) => v.vote === "accept").length;
    if (accepts >= parseInt(requiredAccepts)) {
      complaint.status = "Approved";
      await ctx.stub.setEvent(
        "SettlementTriggered",
        Buffer.from(JSON.stringify({ complaintId }))
      );
    } else {
      const allParties = [
        "ShamsMSP",
        "RebarMSP",
        "TransportMSP",
        "CustomerMSP",
      ];
      const votedOrgs = complaint.votes.map((v) => v.org);
      if (allParties.every((org) => votedOrgs.includes(org))) {
        complaint.status = "Rejected";
      }
    }

    await ctx.stub.putState(
      complaintId,
      Buffer.from(JSON.stringify(complaint))
    );
    return complaint;
  }

  async readComplaint(ctx, complaintId) {
    const buf = await ctx.stub.getState(complaintId);
    if (!buf || buf.length === 0)
      throw new Error(`Complaint ${complaintId} not found`);
    return JSON.parse(buf.toString());
  }

  async queryAllComplaints(ctx) {
    const query = { selector: { docType: "complaint" } };
    const iterator = await ctx.stub.getQueryResult(JSON.stringify(query));
    const results = [];
    while (true) {
      const res = await iterator.next();
      if (res.value) results.push(JSON.parse(res.value.value.toString("utf8")));
      if (res.done) break;
    }
    return results;
  }
}

module.exports = ComplaintContract;
