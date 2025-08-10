'use strict';
const { Contract } = require('fabric-contract-api');
class ShamsContract extends Contract {
    async initLedger(ctx) {
        console.log('Shams ledger initialized');
    }
}
module.exports = { ShamsContract };
