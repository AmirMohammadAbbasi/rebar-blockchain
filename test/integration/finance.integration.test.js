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
