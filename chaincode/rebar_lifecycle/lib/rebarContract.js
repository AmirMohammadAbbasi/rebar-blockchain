'use strict';
const { Contract } = require('fabric-contract-api');

class RebarContract extends Contract {
  async createRebarBundle(ctx, id, shamsId, producer, size, status, date) {
    const bundle = { id, shamsId, producer, size, status, date };
    await ctx.stub.putState('bundle:' + id, Buffer.from(JSON.stringify(bundle)));
  }
  async updateRebarStatus(ctx, id, status) {
    const data = await ctx.stub.getState('bundle:' + id);
    if (!data || data.length === 0) throw new Error(`Bundle ${id} not found`);
    let bundle = JSON.parse(data.toString());
    bundle.status = status;
    await ctx.stub.putState('bundle:' + id, Buffer.from(JSON.stringify(bundle)));
  }
}
module.exports = { RebarContract };
