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
