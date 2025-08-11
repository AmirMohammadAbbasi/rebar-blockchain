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
