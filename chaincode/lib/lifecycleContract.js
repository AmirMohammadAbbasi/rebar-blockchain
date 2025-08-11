"use strict";
const { Contract } = require("fabric-contract-api");

class LifecycleContract extends Contract {
  async getProductLifecycle(ctx, productId) {
    const iterator = await ctx.stub.getHistoryForKey(productId);
    const history = [];
    for await (const res of iterator) {
      if (res.value) {
        let val;
        try {
          val = JSON.parse(res.value.value.toString("utf8"));
        } catch {
          val = res.value.value.toString("utf8");
        }
        history.push({
          txId: res.tx_id,
          timestamp: res.timestamp,
          value: val,
        });
      }
    }
    await iterator.close();
    return history;
  }
}

module.exports = LifecycleContract;
