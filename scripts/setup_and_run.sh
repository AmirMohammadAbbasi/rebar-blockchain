#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHAINCODE_DIR="$ROOT_DIR/chaincode"
TEST_DIR="$ROOT_DIR/test"

echo "Creating project structure..."
mkdir -p "$CHAINCODE_DIR/lib"
mkdir -p "$TEST_DIR"
mkdir -p "$ROOT_DIR/scripts"

# Write package.json
cat > "$CHAINCODE_DIR/package.json" <<'EOF'
{
  "name": "rebar-shams-chaincode",
  "version": "1.0.0",
  "description": "Chaincode for rebar lifecycle: shams and bundles",
  "main": "index.js",
  "scripts": {
    "test": "mocha --exit",
    "start": "node index.js"
  },
  "dependencies": {
    "fabric-contract-api": "^2.5.0",
    "fabric-shim": "^2.5.0"
  },
  "devDependencies": {
    "mocha": "^10.2.0",
    "chai": "^4.3.7",
    "sinon": "^15.2.0",
    "fabric-shim-crypto": "^1.0.0"
  }
}
EOF

# Write index.js
cat > "$CHAINCODE_DIR/index.js" <<'EOF'
'use strict';

const ShamsContract = require('./lib/shamsContract');

module.exports.ShamsContract = ShamsContract;
module.exports.contracts = [ new ShamsContract() ];
EOF

# Write shamsContract.js (use the same implementation provided earlier)
cat > "$CHAINCODE_DIR/lib/shamsContract.js" <<'EOF'
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
EOF

# Write test file
cat > "$TEST_DIR/shamsContract.test.js" <<'EOF'
'use strict';

const chai = require('chai');
const expect = chai.expect;
const sinon = require('sinon');
const { ChaincodeMockStub } = require('fabric-shim');
const ShamsContract = require('../chaincode/lib/shamsContract');

describe('ShamsContract (unit)', () => {
  let contract;
  let stub;

  beforeEach(() => {
    contract = new ShamsContract();
    stub = new ChaincodeMockStub('ShamsStub', contract);
  });

  it('Init should return without error', async () => {
    const response = await contract.Init(stub);
    expect(response).to.be.undefined;
  });

  it('CreateShams should create a shams asset', async () => {
    stub.clientIdentity = { getMSPID: () => 'ShamsMSP' };
    const shams = { id: 'SHAMS001', origin: 'MineA', specs: { grade: 'A' }, manufactureDate: '2025-08-11', producer: 'ShamsCo' };
    const res = await contract.CreateShams(stub, JSON.stringify(shams));
    const stored = await stub.getState(shams.id);
    expect(stored).to.not.be.null;
    const obj = JSON.parse(stored.toString());
    expect(obj.id).to.equal('SHAMS001');
  });

  it('CreateMilgardBundle should fail if shams missing', async () => {
    stub.clientIdentity = { getMSPID: () => 'RebarMSP' };
    const bundle = { id: 'B001', shamsId: 'UNKNOWN' };
    try {
      await contract.CreateMilgardBundle(stub, JSON.stringify(bundle));
      throw new Error('Expected error');
    } catch (err) {
      expect(err.message).to.match(/referenced shams .* does not exist/);
    }
  });

  it('CreateMilgardBundle should create bundle when shams exists', async () => {
    stub.clientIdentity = { getMSPID: () => 'ShamsMSP' };
    await contract.CreateShams(stub, JSON.stringify({ id: 'SHAMS100', origin: 'MineX' }));

    stub.clientIdentity = { getMSPID: () => 'RebarMSP' };
    await contract.CreateMilgardBundle(stub, JSON.stringify({ id: 'B100', shamsId: 'SHAMS100', weight: 100 }));

    const stored = await stub.getState('B100');
    expect(stored).to.not.be.null;
    const obj = JSON.parse(stored.toString());
    expect(obj.shamsId).to.equal('SHAMS100');
  });

  it('UpdateBundleStatus allowed MSPs update status', async () => {
    stub.clientIdentity = { getMSPID: () => 'ShamsMSP' };
    await contract.CreateShams(stub, JSON.stringify({ id: 'S200' }));
    stub.clientIdentity = { getMSPID: () => 'RebarMSP' };
    await contract.CreateMilgardBundle(stub, JSON.stringify({ id: 'B200', shamsId: 'S200' }));

    stub.clientIdentity = { getMSPID: () => 'TransportMSP' };
    await contract.UpdateBundleStatus(stub, 'B200', 'InTransit', JSON.stringify({ location: 'Truck1' }));

    const stored = JSON.parse((await stub.getState('B200')).toString());
    expect(stored.status).to.equal('InTransit');
    expect(stored.metadata.location).to.equal('Truck1');
  });

  it('QueryBundleHistory returns history array', async () => {
    stub.clientIdentity = { getMSPID: () => 'ShamsMSP' };
    await contract.CreateShams(stub, JSON.stringify({ id: 'S300' }));
    stub.clientIdentity = { getMSPID: () => 'RebarMSP' };
    await contract.CreateMilgardBundle(stub, JSON.stringify({ id: 'B300', shamsId: 'S300' }));
    stub.clientIdentity = { getMSPID: () => 'TransportMSP' };
    await contract.UpdateBundleStatus(stub, 'B300', 'InTransit');

    const hist = await contract.QueryBundleHistory(stub, 'B300');
    const arr = JSON.parse(hist);
    expect(arr).to.be.an('array');
    expect(arr.length).to.be.greaterThan(0);
  });

});
EOF

# Install node deps
echo "Installing node dependencies in $CHAINCODE_DIR..."
pushd "$CHAINCODE_DIR" > /dev/null
npm install --no-audit --no-fund
popd > /dev/null

# Run mocha tests
echo "Running unit tests (mocha)..."
pushd "$CHAINCODE_DIR" > /dev/null
npm test
TEST_EXIT=$?
popd > /dev/null

if [ $TEST_EXIT -ne 0 ]; then
  echo "Tests failed. See output above."
  exit $TEST_EXIT
fi

# Package chaincode (requires peer CLI in PATH if you want to actually package; here we create a tar.gz as placeholder)
echo "Packaging chaincode as rebarcc.tar.gz..."
pushd "$CHAINCODE_DIR" > /dev/null
tar -czf ../rebarcc.tar.gz ./*
popd > /dev/null

echo "All done. Created:"
echo " - Chaincode at: $CHAINCODE_DIR"
echo " - Tests at: $TEST_DIR"
echo " - Packaged archive: $ROOT_DIR/rebarcc.tar.gz"
echo " - To install package with peer CLI, copy rebarcc.tar.gz to a peer host and run peer lifecycle chaincode install rebarcc.tar.gz"

exit 0
