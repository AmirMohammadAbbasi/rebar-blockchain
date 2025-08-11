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
