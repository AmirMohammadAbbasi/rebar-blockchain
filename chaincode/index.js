'use strict';

const ShamsContract = require('./lib/shamsContract');

module.exports.ShamsContract = ShamsContract;
module.exports.contracts = [ new ShamsContract() ];
