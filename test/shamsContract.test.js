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
