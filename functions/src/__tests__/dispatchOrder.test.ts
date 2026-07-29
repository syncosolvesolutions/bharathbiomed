import {getFirestore} from "firebase-admin/firestore";
import {dispatchOrder} from "../index";
import {callableRequest, clearFirestore, seedUser, testEnv} from "./helpers";

const wrapped = testEnv.wrap(dispatchOrder);
const firestore = getFirestore();

afterAll(() => testEnv.cleanup());

beforeEach(async () => {
  await clearFirestore(firestore);
});

describe("dispatchOrder", () => {
  test("decrements stock and marks the order dispatched for an approved order", async () => {
    await seedUser(firestore, "manager1", {role: "mr", permissions: ["dispatch_orders"]});
    await firestore.collection("Products").doc("p1").set({name: "Paracetamol", stockQuantity: 100});
    await firestore.collection("Orders").doc("o1").set({
      status: "approved",
      items: [{productId: "p1", quantity: 10}],
    });

    const result = await wrapped(callableRequest({orderId: "o1"}, {uid: "manager1"}));

    expect(result).toEqual({success: true});
    const product = await firestore.collection("Products").doc("p1").get();
    expect(product.data()?.stockQuantity).toBe(90);
    const order = await firestore.collection("Orders").doc("o1").get();
    expect(order.data()?.status).toBe("dispatched");
    expect(order.data()?.dispatchedByUid).toBe("manager1");
  });

  test("consumes batches oldest-expiry-first (FEFO), spanning multiple batches if needed", async () => {
    await seedUser(firestore, "manager1", {role: "mr", permissions: ["dispatch_orders"]});
    await firestore.collection("Products").doc("p1").set({name: "Paracetamol", stockQuantity: 100});
    const batches = firestore.collection("Products").doc("p1").collection("Batches");
    await batches.doc("later").set({batchNumber: "B2", expiryDate: "2027-06-01", quantity: 20});
    await batches.doc("sooner").set({batchNumber: "B1", expiryDate: "2027-01-01", quantity: 5});
    await firestore.collection("Orders").doc("o1").set({
      status: "approved",
      items: [{productId: "p1", quantity: 10}],
    });

    await wrapped(callableRequest({orderId: "o1"}, {uid: "manager1"}));

    // 10 dispatched: fully drains the sooner-expiring 5-unit batch first,
    // then takes the remaining 5 from the later-expiring 20-unit batch.
    const sooner = await batches.doc("sooner").get();
    const later = await batches.doc("later").get();
    expect(sooner.data()?.quantity).toBe(0);
    expect(later.data()?.quantity).toBe(15);
  });

  test("still dispatches when a product has no tracked batches at all", async () => {
    await seedUser(firestore, "manager1", {role: "mr", permissions: ["dispatch_orders"]});
    await firestore.collection("Products").doc("p1").set({name: "Paracetamol", stockQuantity: 100});
    await firestore.collection("Orders").doc("o1").set({
      status: "approved",
      items: [{productId: "p1", quantity: 10}],
    });

    const result = await wrapped(callableRequest({orderId: "o1"}, {uid: "manager1"}));

    expect(result).toEqual({success: true});
    const product = await firestore.collection("Products").doc("p1").get();
    expect(product.data()?.stockQuantity).toBe(90);
  });

  test("rejects an order that is not currently approved", async () => {
    await seedUser(firestore, "manager1", {role: "mr", permissions: ["dispatch_orders"]});
    await firestore.collection("Orders").doc("o1").set({status: "pending", items: []});

    await expect(wrapped(callableRequest({orderId: "o1"}, {uid: "manager1"}))).rejects.toThrow(
      "Only an approved order can be dispatched."
    );
  });

  test("rejects a caller without the dispatch_orders permission", async () => {
    await seedUser(firestore, "manager1", {role: "mr", permissions: []});
    await firestore.collection("Orders").doc("o1").set({status: "approved", items: []});

    await expect(wrapped(callableRequest({orderId: "o1"}, {uid: "manager1"}))).rejects.toThrow(
      /dispatch_orders/
    );
  });

  test("rejects a missing orderId", async () => {
    await seedUser(firestore, "manager1", {role: "mr", permissions: ["dispatch_orders"]});

    await expect(wrapped(callableRequest({}, {uid: "manager1"}))).rejects.toThrow("orderId is required.");
  });
});
