'use strict';

const { Contract } = require('fabric-contract-api');

class ShamsContract extends Contract {
  constructor() {
    super('rebar.shams.contract');
  }

  async Init(ctx) {
    console.info('Ledger initialized for rebar lifecycle');
    return;
  }

  _createShamsObject(input) {
    return {
      docType: 'shams',
      id: input.id,
      origin: input.origin || '',
      specs: input.specs || {},
      manufactureDate: input.manufactureDate || '',
      producer: input.producer || '',
      additional: input.additional || {}
    };
  }

  _createBundleObject(input) {
    return {
      docType: 'bundle',
      id: input.id,
      shamsId: input.shamsId,
      weight: input.weight || 0,
      length: input.length || 0,
      producedAt: input.producedAt || '',
      status: input.status || 'Created',
      owner: input.owner || '',
      metadata: input.metadata || {}
    };
  }

  _getClientOrgId(ctx) {
    const cid = ctx.clientIdentity;
    const mspid = cid.getMSPID();
    return mspid;
  }

  async CreateShams(ctx, shamsJson) {
    const callerMsp = this._getClientOrgId(ctx);
    if (callerMsp !== 'ShamsMSP') {
      throw new Error('CreateShams: Only ShamsMSP can create raw shams records');
    }

    const input = JSON.parse(shamsJson);
    if (!input.id) throw new Error('CreateShams: id is required');

    const exists = await ctx.stub.getState(input.id);
    if (exists && exists.length > 0) {
      throw new Error(`CreateShams: asset ${input.id} already exists`);
    }

    const shamsObj = this._createShamsObject(input);
    await ctx.stub.putState(shamsObj.id, Buffer.from(JSON.stringify(shamsObj)));
    await ctx.stub.setEvent('ShamsCreated', Buffer.from(JSON.stringify({ id: shamsObj.id })));
    return JSON.stringify(shamsObj);
  }

  async CreateMilgardBundle(ctx, bundleJson) {
    const callerMsp = this._getClientOrgId(ctx);
    if (callerMsp !== 'RebarMSP') {
      throw new Error('CreateMilgardBundle: Only RebarMSP can create bundles');
    }

    const input = JSON.parse(bundleJson);
    if (!input.id || !input.shamsId) throw new Error('CreateMilgardBundle: id and shamsId are required');

    const shamsState = await ctx.stub.getState(input.shamsId);
    if (!shamsState || shamsState.length === 0) {
      throw new Error(`CreateMilgardBundle: referenced shams ${input.shamsId} does not exist`);
    }

    const bundleExists = await ctx.stub.getState(input.id);
    if (bundleExists && bundleExists.length > 0) {
      throw new Error(`CreateMilgardBundle: bundle ${input.id} already exists`);
    }

    const bundleObj = this._createBundleObject(input);
    bundleObj.owner = input.owner || callerMsp;

    await ctx.stub.putState(bundleObj.id, Buffer.from(JSON.stringify(bundleObj)));
    await ctx.stub.setEvent('BundleCreated', Buffer.from(JSON.stringify({ id: bundleObj.id, shamsId: bundleObj.shamsId })));

    return JSON.stringify(bundleObj);
  }

  async UpdateBundleStatus(ctx, bundleId, newStatus, additionalJson) {
    const callerMsp = this._getClientOrgId(ctx);
    const allowed = ['TransportMSP', 'RebarMSP', 'ShamsMSP', 'CustomerMSP'];
    if (!allowed.includes(callerMsp)) {
      throw new Error('UpdateBundleStatus: MSP not authorized to update status');
    }

    const bundleBytes = await ctx.stub.getState(bundleId);
    if (!bundleBytes || bundleBytes.length === 0) {
      throw new Error(`UpdateBundleStatus: bundle ${bundleId} does not exist`);
    }

    const bundle = JSON.parse(bundleBytes.toString());
    const prevStatus = bundle.status;
    bundle.status = newStatus;
    if (additionalJson) {
      try {
        const add = JSON.parse(additionalJson);
        bundle.metadata = { ...(bundle.metadata || {}), ...add };
      } catch (err) {
        throw new Error('UpdateBundleStatus: additionalJson must be valid JSON');
      }
    }

    const time = new Date().toISOString();
    bundle.metadata = bundle.metadata || {};
    bundle.metadata.lastUpdated = { by: callerMsp, at: time, prevStatus };

    await ctx.stub.putState(bundleId, Buffer.from(JSON.stringify(bundle)));
    await ctx.stub.setEvent('BundleStatusUpdated', Buffer.from(JSON.stringify({ id: bundleId, status: newStatus })));

    return JSON.stringify(bundle);
  }

  async QueryBundleHistory(ctx, bundleId) {
    const iterator = await ctx.stub.getHistoryForKey(bundleId);
    const results = [];
    while (true) {
      const res = await iterator.next();
      if (res.value) {
        const tx = {
          txId: res.value.txId,
          timestamp: res.value.timestamp,
          isDelete: res.value.isDelete,
          value: null
        };
        if (res.value.value && res.value.value.length > 0) {
          try {
            tx.value = JSON.parse(res.value.value.toString('utf8'));
          } catch (e) {
            tx.value = res.value.value.toString('utf8');
          }
        }
        results.push(tx);
      }
      if (res.done) {
        await iterator.close();
        break;
      }
    }
    return JSON.stringify(results);
  }

  async QueryAllBundles(ctx) {
    const queryString = {
      selector: {
        docType: 'bundle'
      }
    };
    const iterator = await ctx.stub.getQueryResult(JSON.stringify(queryString));
    const results = [];
    while (true) {
      const res = await iterator.next();
      if (res.value) {
        const record = JSON.parse(res.value.value.toString('utf8'));
        results.push(record);
      }
      if (res.done) {
        await iterator.close();
        break;
      }
    }
    return JSON.stringify(results);
  }

  async ReadBundle(ctx, bundleId) {
    const b = await ctx.stub.getState(bundleId);
    if (!b || b.length === 0) {
      throw new Error(`ReadBundle: bundle ${bundleId} does not exist`);
    }
    return b.toString();
  }
}

module.exports = ShamsContract;
