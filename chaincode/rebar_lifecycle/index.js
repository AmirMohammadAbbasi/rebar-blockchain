'use strict';
const { ShamsContract } = require('./lib/shamsContract');
const { RebarContract } = require('./lib/rebarContract');
const { QualityContract } = require('./lib/qualityContract');

module.exports.contracts = [ShamsContract, RebarContract, QualityContract];
