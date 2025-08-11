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
