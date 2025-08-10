'use strict';
const { Contract } = require('fabric-contract-api');

class ShamsContract extends Contract {
  async initLedger(ctx) {
    console.log('Ledger initialized with sample data');
  }
  async createShams(ctx, id, producer, batchNo, date) {
    const shams = { id, producer, batchNo, date };
    await ctx.stub.putState('shams:' + id, Buffer.from(JSON.stringify(shams)));
  }
  async queryShams(ctx, id) {
    const data = await ctx.stub.getState('shams:' + id);
    if (!data || data.length === 0) throw new Error(`Shams ${id} not found`);
    return data.toString();
  }
}
module.exports = { ShamsContract };
