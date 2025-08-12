"use strict";

const ShamsContract = require("./lib/shamsContract");
const RebarContract = require("./lib/rebarContract");
const FinanceContract = require("./lib/financeContract");
const LifecycleContract = require("./lib/lifecycleContract");

module.exports.contracts = [
  ShamsContract,
  RebarContract,
  FinanceContract,
  LifecycleContract,
];
