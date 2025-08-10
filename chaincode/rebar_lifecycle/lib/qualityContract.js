'use strict';
const { Contract } = require('fabric-contract-api');

class QualityContract extends Contract {
  async addQualityCert(ctx, id, relatedId, issuer, result, notes, date) {
    const cert = { id, relatedId, issuer, result, notes, date };
    await ctx.stub.putState('cert:' + id, Buffer.from(JSON.stringify(cert)));
  }
  async queryCert(ctx, id) {
    const data = await ctx.stub.getState('cert:' + id);
    if (!data || data.length === 0) throw new Error(`Cert ${id} not found`);
    return data.toString();
  }
}
module.exports = { QualityContract };
