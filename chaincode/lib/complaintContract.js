"use strict";
const { Contract } = require("fabric-contract-api");

class ComplaintContract extends Contract {
  constructor() {
    super("rebar.complaint.contract");
    // وزن هر سازمان
    this.orgWeights = {
      ShamsMSP: 2, // تولید شمش
      RebarMSP: 2, // کارخانه نورد
      TransportMSP: 1, // حمل و نقل
      CustomerMSP: 1, // مشتری
    };
  }

  _getClientOrgId(ctx) {
    return ctx.clientIdentity.getMSPID();
  }

  async registerComplaint(ctx, targetId, type, description, evidenceHash) {
    const callerMsp = this._getClientOrgId(ctx);
    const allowed = Object.keys(this.orgWeights);
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
    if (!buf || buf.length === 0)
      throw new Error(`Complaint ${complaintId} not found`);

    const complaint = JSON.parse(buf.toString());
    if (complaint.status !== "PendingVoting") {
      throw new Error(`Voting closed for complaint ${complaintId}`);
    }

    if (complaint.votes.some((v) => v.org === callerMsp)) {
      throw new Error(`Org ${callerMsp} already voted`);
    }

    if (!Object.keys(this.orgWeights).includes(callerMsp)) {
      throw new Error(`Org ${callerMsp} not authorized to vote`);
    }

    complaint.votes.push({
      org: callerMsp,
      weight: this.orgWeights[callerMsp],
      vote,
      at: new Date().toISOString(),
    });

    await ctx.stub.putState(
      complaintId,
      Buffer.from(JSON.stringify(complaint))
    );
    return complaint;
  }

  async checkConsensus(ctx, complaintId, requiredWeight) {
    const buf = await ctx.stub.getState(complaintId);
    if (!buf || buf.length === 0)
      throw new Error(`Complaint ${complaintId} not found`);

    const complaint = JSON.parse(buf.toString());
    if (complaint.status !== "PendingVoting") {
      return complaint;
    }

    // محاسبه وزن موافق‌ها
    const acceptWeight = complaint.votes
      .filter((v) => v.vote === "accept")
      .reduce((sum, v) => sum + v.weight, 0);

    if (acceptWeight >= parseInt(requiredWeight)) {
      complaint.status = "Approved";
      await ctx.stub.setEvent(
        "SettlementTriggered",
        Buffer.from(JSON.stringify({ complaintId }))
      );
    } else {
      // اگر همه رأی داده باشند اما به حد نصاب نرسد → رد شده
      const votedOrgs = complaint.votes.map((v) => v.org);
      const allVoted = Object.keys(this.orgWeights).every((org) =>
        votedOrgs.includes(org)
      );
      if (allVoted) {
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
