#!/bin/bash
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)

echo "📂 Creating integration tests folder..."
mkdir -p "$ROOT/test/integration"

#######################################
# ShamsContract Integration Test
#######################################
cat > "$ROOT/test/integration/shams.integration.test.js" <<'EOF'
'use strict';
const { Gateway, Wallets } = require('fabric-network');
const path = require('path');
const fs = require('fs');
const chai = require('chai');
const expect = chai.expect;

async function connectAs(identity, org) {
  const ccpPath = path.resolve(__dirname, `../../connection-${org}.json`);
  const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));
  const wallet = await Wallets.newFileSystemWallet(path.resolve(__dirname, '../../wallet'));
  const gateway = new Gateway();
  await gateway.connect(ccp, { wallet, identity, discovery: { enabled: true, asLocalhost: true } });
  return gateway;
}

describe('Integration - ShamsContract', function() {
  this.timeout(20000);

  it('should register a shams batch (success)', async () => {
    const gateway = await connectAs('ShamsUser', 'org1');
    const network = await gateway.getNetwork('rebar-channel');
    const contract = network.getContract('rebarcc', 'ShamsContract');

    const shams = { batchNo: 'S_INT_001', origin: 'MineA', specs: { grade: 'A' } };
    const purchase = { po: 'PO_INT_001' };
    const result = await contract.submitTransaction('registerShamsBatch',
      JSON.stringify(shams), JSON.stringify(purchase));
    const parsed = JSON.parse(result.toString());
    expect(parsed.batchNo).to.equal('S_INT_001');
    await gateway.disconnect();
  });

  it('should fail for non-ShamsMSP user', async () => {
    const gateway = await connectAs('RebarUser', 'org2');
    const network = await gateway.getNetwork('rebar-channel');
    const contract = network.getContract('rebarcc', 'ShamsContract');

    try {
      await contract.submitTransaction('registerShamsBatch', '{}', '{}');
      throw new Error('Expected MSP error');
    } catch (err) {
      expect(err.message).to.match(/Only ShamsMSP/);
    }
    await gateway.disconnect();
  });
});
EOF

#######################################
# RebarContract Integration Test
#######################################
cat > "$ROOT/test/integration/rebar.integration.test.js" <<'EOF'
'use strict';
const { Gateway, Wallets } = require('fabric-network');
const path = require('path');
const fs = require('fs');
const chai = require('chai');
const expect = chai.expect;
async function connectAs(identity, org) {
  const ccpPath = path.resolve(__dirname, `../../connection-${org}.json`);
  const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));
  const wallet = await Wallets.newFileSystemWallet(path.resolve(__dirname, '../../wallet'));
  const gateway = new Gateway();
  await gateway.connect(ccp, { wallet, identity, discovery: { enabled: true, asLocalhost: true } });
  return gateway;
}

describe('Integration - RebarContract', function() {
  this.timeout(20000);

  it('should produce rebar from existing shams batch', async () => {
    const gateway = await connectAs('RebarUser', 'org2');
    const network = await gateway.getNetwork('rebar-channel');
    const contract = network.getContract('rebarcc', 'RebarContract');
    const rebar = { batchNo: 'RB_INT_001', sourceShamsBatch: 'S_INT_001' };
    const result = await contract.submitTransaction('produceRebarFromShams',
      JSON.stringify(rebar), JSON.stringify({ furnace: 'FM-1' }));
    const parsed = JSON.parse(result.toString());
    expect(parsed.batchNo).to.equal('RB_INT_001');
    await gateway.disconnect();
  });

  it('should fail for missing shams batch', async () => {
    const gateway = await connectAs('RebarUser', 'org2');
    const network = await gateway.getNetwork('rebar-channel');
    const contract = network.getContract('rebarcc', 'RebarContract');
    try {
      await contract.submitTransaction('produceRebarFromShams',
        '{"batchNo":"RB_ERR","sourceShamsBatch":"NO_SUCH"}', '{}');
      throw new Error('Expected missing shams error');
    } catch (err) {
      expect(err.message).to.match(/not found/i);
    }
    await gateway.disconnect();
  });
});
EOF

#######################################
# FinanceContract Integration Test
#######################################
cat > "$ROOT/test/integration/finance.integration.test.js" <<'EOF'
'use strict';
const { Gateway, Wallets } = require('fabric-network');
const path = require('path');
const fs = require('fs');
const chai = require('chai');
const expect = chai.expect;
async function connectAs(identity, org) {
  const ccpPath = path.resolve(__dirname, `../../connection-${org}.json`);
  const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));
  const wallet = await Wallets.newFileSystemWallet(path.resolve(__dirname, '../../wallet'));
  const gateway = new Gateway();
  await gateway.connect(ccp, { wallet, identity, discovery: { enabled: true, asLocalhost: true } });
  return gateway;
}
describe('Integration - FinanceContract', function() {
  this.timeout(20000);

  it('should create sales order and hash invoice', async () => {
    const gateway = await connectAs('FinanceUser', 'org3');
    const network = await gateway.getNetwork('rebar-channel');
    const contract = network.getContract('rebarcc', 'FinanceContract');
    const order = { orderNo: 'SO_INT_001', customer: 'CustA', invoice: { amount: 9000 } };
    const res = await contract.submitTransaction('createSalesOrder', JSON.stringify(order));
    const parsed = JSON.parse(res.toString());
    expect(parsed.invoiceHash).to.be.a('string');
    await gateway.disconnect();
  });

  it('should update payment status', async () => {
    const gateway = await connectAs('FinanceUser', 'org3');
    const network = await gateway.getNetwork('rebar-channel');
    const contract = network.getContract('rebarcc', 'FinanceContract');
    const res = await contract.submitTransaction('updatePaymentStatus', 'ORDER_SO_INT_001', 'Paid');
    const parsed = JSON.parse(res.toString());
    expect(parsed.paymentStatus).to.equal('Paid');
    await gateway.disconnect();
  });
});
EOF

#######################################
# LifecycleContract Integration Test
#######################################
cat > "$ROOT/test/integration/lifecycle.integration.test.js" <<'EOF'
'use strict';
const { Gateway, Wallets } = require('fabric-network');
const path = require('path');
const fs = require('fs');
const chai = require('chai');
const expect = chai.expect;
async function connectAs(identity, org) {
  const ccpPath = path.resolve(__dirname, `../../connection-${org}.json`);
  const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));
  const wallet = await Wallets.newFileSystemWallet(path.resolve(__dirname, '../../wallet'));
  const gateway = new Gateway();
  await gateway.connect(ccp, { wallet, identity, discovery: { enabled: true, asLocalhost: true } });
  return gateway;
}
describe('Integration - LifecycleContract', function() {
  this.timeout(20000);
  it('should track lifecycle for an asset', async () => {
    const gateway = await connectAs('LifecycleUser', 'org4');
    const network = await gateway.getNetwork('rebar-channel');
    const contract = network.getContract('rebarcc', 'LifecycleContract');
    const res = await contract.evaluateTransaction('getProductLifecycle', 'S_INT_001');
    const parsed = JSON.parse(res.toString());
    expect(parsed).to.be.an('array');
    await gateway.disconnect();
  });
});
EOF

#######################################
# Full Cycle Integration Test
#######################################
cat > "$ROOT/test/integration/full-cycle.integration.test.js" <<'EOF'
'use strict';
const { Gateway, Wallets } = require('fabric-network');
const path = require('path');
const fs = require('fs');
const chai = require('chai');
const expect = chai.expect;

async function connectAs(identity, org) {
  const ccpPath = path.resolve(__dirname, `../../connection-${org}.json`);
  const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));
  const wallet = await Wallets.newFileSystemWallet(path.resolve(__dirname, '../../wallet'));
  const gateway = new Gateway();
  await gateway.connect(ccp, { wallet, identity, discovery: { enabled: true, asLocalhost: true } });
  return gateway;
}

describe('Integration - Full 5 Stage Lifecycle', function() {
  this.timeout(30000);

  it('should execute all stages without error', async () => {
    // Stage 1: Shams Registration
    let gw = await connectAs('ShamsUser', 'org1');
    let net = await gw.getNetwork('rebar-channel');
    let shamsContract = net.getContract('rebarcc', 'ShamsContract');
    await shamsContract.submitTransaction('registerShamsBatch',
      JSON.stringify({ batchNo: 'S_FULL_001', origin: 'MineQ' }),
      JSON.stringify({ po: 'PO_FULL_001' }));
    await gw.disconnect();

    // Stage 2: Rebar Production
    gw = await connectAs('RebarUser', 'org2');
    net = await gw.getNetwork('rebar-channel');
    let rebarContract = net.getContract('rebarcc', 'RebarContract');
    await rebarContract.submitTransaction('produceRebarFromShams',
      JSON.stringify({ batchNo: 'RB_FULL_001', sourceShamsBatch: 'S_FULL_001' }),
      JSON.stringify({ furnace: 'F1' }));
    await gw.disconnect();

    // Stage 3: Add Quality Cert
    gw = await connectAs('RebarUser', 'org2');
    net = await gw.getNetwork('rebar-channel');
    rebarContract = net.getContract('rebarcc', 'RebarContract');
    await rebarContract.submitTransaction('addQualityCertificate', 'REBAR_RB_FULL_001', 'hash-qc-full');
    await gw.disconnect();

    // Stage 4: Record Transport
    gw = await connectAs('LifecycleUser', 'org4');
    net = await gw.getNetwork('rebar-channel');
    let lifecycleContract = net.getContract('rebarcc', 'LifecycleContract');
    await lifecycleContract.submitTransaction('recordTransport', JSON.stringify({ packageId: 'PKG_FULL_1', destination: 'CustZ' }));
    await gw.disconnect();

    // Stage 5: Sales Order + Payment
    gw = await connectAs('FinanceUser', 'org3');
    net = await gw.getNetwork('rebar-channel');
    let financeContract = net.getContract('rebarcc', 'FinanceContract');
    await financeContract.submitTransaction('createSalesOrder',
      JSON.stringify({ orderNo: 'SO_FULL_001', customer: 'CustZ', invoice: { amount: 5500 } }));
    await financeContract.submitTransaction('updatePaymentStatus', 'ORDER_SO_FULL_001', 'Paid');
    await gw.disconnect();

    // Verify Lifecycle Query
    gw = await connectAs('LifecycleUser', 'org4');
    net = await gw.getNetwork('rebar-channel');
    lifecycleContract = net.getContract('rebarcc', 'LifecycleContract');
    const queryRes = await lifecycleContract.evaluateTransaction('getProductLifecycle', 'S_FULL_001');
    const parsed = JSON.parse(queryRes.toString());
    expect(parsed.length).to.be.greaterThan(0);
    await gw.disconnect();
  });
});
EOF

#######################################
# Install Dependencies
#######################################
echo "📦 Installing Fabric SDK for integration tests..."
pushd "$ROOT/chaincode" > /dev/null
npm install fabric-network@^2.2 --save-dev
popd > /dev/null

echo "✅ Integration tests added successfully."
