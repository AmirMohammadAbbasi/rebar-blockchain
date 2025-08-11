"use strict";
const { Contract } = require("fabric-contract-api");
const crypto = require("crypto");

class FinanceContract extends Contract {
  _hashSensitive(data) {
    return crypto
      .createHash("sha256")
      .update(JSON.stringify(data))
      .digest("hex");
  }

  async createSalesOrder(ctx, orderJson) {
    const order = JSON.parse(orderJson);
    const id = `ORDER_${order.orderNo}`;
    order.docType = "salesOrder";
    order.createdAt = new Date().toISOString();
    order.invoiceHash = this._hashSensitive(order.invoice); // invoice details hashed
    delete order.invoice;
    await ctx.stub.putState(id, Buffer.from(JSON.stringify(order)));
    await ctx.stub.setEvent(
      "SalesOrderCreated",
      Buffer.from(JSON.stringify({ id }))
    );
    return order;
  }

  async updatePaymentStatus(ctx, orderId, status) {
    const buf = await ctx.stub.getState(orderId);
    if (!buf || buf.length === 0) throw new Error(`Order ${orderId} not found`);
    const rec = JSON.parse(buf.toString());
    rec.paymentStatus = status;
    rec.updatedAt = new Date().toISOString();
    await ctx.stub.putState(orderId, Buffer.from(JSON.stringify(rec)));
    await ctx.stub.setEvent(
      "PaymentStatusUpdated",
      Buffer.from(JSON.stringify({ orderId, status }))
    );
    return rec;
  }
}

module.exports = FinanceContract;
