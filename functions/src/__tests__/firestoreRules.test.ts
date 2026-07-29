import * as fs from "fs";
import * as path from "path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";

// firestore.rules lives at the repo root, not under functions/ — this suite
// exercises the actual deployed rules file directly (loaded fresh into the
// emulator below), not a copy.
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

let testEnv: RulesTestEnvironment;

const ADMIN_EMAIL = "bharathbiomedpharma@gmail.com";

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-bharathbiomedpharma-rules",
    firestore: {
      rules: fs.readFileSync(RULES_PATH, "utf8"),
      host: "localhost",
      port: 8080,
    },
  });
});

afterAll(() => testEnv.cleanup());

afterEach(() => testEnv.clearFirestore());

/** Seeds Firestore directly, bypassing security rules entirely. */
async function seed(fn: (db: FirebaseFirestore.Firestore) => Promise<unknown>): Promise<void> {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    // The admin SDK types differ slightly from the client SDK types
    // rules-unit-testing hands back; both support the same Firestore API
    // surface used here.
    await fn(context.firestore() as unknown as FirebaseFirestore.Firestore);
  });
}

describe("Products", () => {
  test("any signed-in user can read", async () => {
    await seed((db) => db.doc("Products/p1").set({name: "Paracetamol", stockQuantity: 10}));
    const mr = testEnv.authenticatedContext("mr1").firestore();

    await assertSucceeds(mr.doc("Products/p1").get());
  });

  test("an unauthenticated caller cannot read", async () => {
    await seed((db) => db.doc("Products/p1").set({name: "Paracetamol", stockQuantity: 10}));
    const anon = testEnv.unauthenticatedContext().firestore();

    await assertFails(anon.doc("Products/p1").get());
  });

  test("a non-admin cannot write a full product edit", async () => {
    const mr = testEnv.authenticatedContext("mr1").firestore();

    await assertFails(mr.doc("Products/p1").set({name: "Paracetamol", stockQuantity: 10}));
  });

  test("the admin can write a full product edit", async () => {
    const admin = testEnv.authenticatedContext("admin-uid", {email: ADMIN_EMAIL}).firestore();

    await assertSucceeds(admin.doc("Products/p1").set({name: "Paracetamol", stockQuantity: 10}));
  });

  test("an Office Admin may adjust only stockQuantity, not other fields", async () => {
    await seed((db) => db.doc("Products/p1").set({name: "Paracetamol", stockQuantity: 10}));
    await seed((db) => db.doc("Users/officeadmin1").set({category: "office_administration"}));
    const officeAdmin = testEnv.authenticatedContext("officeadmin1").firestore();

    await assertSucceeds(officeAdmin.doc("Products/p1").update({stockQuantity: 20}));
    await assertFails(officeAdmin.doc("Products/p1").update({name: "Renamed"}));
  });
});

describe("Users", () => {
  test("an employee can read their own doc", async () => {
    await seed((db) => db.doc("Users/mr1").set({username: "mr1"}));
    const mr = testEnv.authenticatedContext("mr1").firestore();

    await assertSucceeds(mr.doc("Users/mr1").get());
  });

  test("an unrelated employee cannot read someone else's doc", async () => {
    await seed((db) => db.doc("Users/mr1").set({username: "mr1"}));
    const other = testEnv.authenticatedContext("mr2").firestore();

    await assertFails(other.doc("Users/mr1").get());
  });

  test("a manager can read someone in their own reporting-chain downline", async () => {
    await seed((db) => db.doc("Users/mr1").set({username: "mr1", reportingChainUids: ["mgr1"]}));
    const manager = testEnv.authenticatedContext("mgr1").firestore();

    await assertSucceeds(manager.doc("Users/mr1").get());
  });

  test("nobody can write directly, not even the admin", async () => {
    const admin = testEnv.authenticatedContext("admin-uid", {email: ADMIN_EMAIL}).firestore();

    await assertFails(admin.doc("Users/mr1").set({username: "mr1"}));
  });
});

describe("Orders", () => {
  test("an MR can create their own pending order", async () => {
    const mr = testEnv.authenticatedContext("mr1").firestore();

    await assertSucceeds(
      mr.collection("Orders").add({createdByUid: "mr1", status: "pending", items: []})
    );
  });

  test("an MR cannot create an order on someone else's behalf", async () => {
    const mr = testEnv.authenticatedContext("mr1").firestore();

    await assertFails(
      mr.collection("Orders").add({createdByUid: "mr2", status: "pending", items: []})
    );
  });

  test("an MR cannot create an order in a non-pending status", async () => {
    const mr = testEnv.authenticatedContext("mr1").firestore();

    await assertFails(
      mr.collection("Orders").add({createdByUid: "mr1", status: "approved", items: []})
    );
  });

  test("an unrelated MR cannot read someone else's order", async () => {
    await seed((db) => db.doc("Orders/o1").set({createdByUid: "mr1", status: "pending"}));
    const other = testEnv.authenticatedContext("mr2").firestore();

    await assertFails(other.doc("Orders/o1").get());
  });

  test("a manager in the creator's reporting chain, holding approve_orders, can approve a pending order", async () => {
    await seed((db) => db.doc("Orders/o1").set({createdByUid: "mr1", status: "pending"}));
    await seed((db) =>
      db.doc("Users/mr1").set({username: "mr1", reportingChainUids: ["mgr1"]})
    );
    await seed((db) => db.doc("Users/mgr1").set({permissions: ["approve_orders"]}));
    const manager = testEnv.authenticatedContext("mgr1").firestore();

    await assertSucceeds(
      manager.doc("Orders/o1").update({status: "approved", approvedByUid: "mgr1"})
    );
  });

  test("a manager without approve_orders cannot approve, even if in the chain", async () => {
    await seed((db) => db.doc("Orders/o1").set({createdByUid: "mr1", status: "pending"}));
    await seed((db) => db.doc("Users/mr1").set({username: "mr1", reportingChainUids: ["mgr1"]}));
    await seed((db) => db.doc("Users/mgr1").set({permissions: []}));
    const manager = testEnv.authenticatedContext("mgr1").firestore();

    await assertFails(manager.doc("Orders/o1").update({status: "approved"}));
  });

  test("approving an order that isn't pending (already decided) is rejected", async () => {
    await seed((db) => db.doc("Orders/o1").set({createdByUid: "mr1", status: "approved"}));
    await seed((db) => db.doc("Users/mr1").set({username: "mr1", reportingChainUids: ["mgr1"]}));
    await seed((db) => db.doc("Users/mgr1").set({permissions: ["approve_orders"]}));
    const manager = testEnv.authenticatedContext("mgr1").firestore();

    await assertFails(manager.doc("Orders/o1").update({status: "rejected"}));
  });

  test("an approval write may only touch the review fields, not e.g. totalValue", async () => {
    await seed((db) => db.doc("Orders/o1").set({createdByUid: "mr1", status: "pending", totalValue: 100}));
    await seed((db) => db.doc("Users/mr1").set({username: "mr1", reportingChainUids: ["mgr1"]}));
    await seed((db) => db.doc("Users/mgr1").set({permissions: ["approve_orders"]}));
    const manager = testEnv.authenticatedContext("mgr1").firestore();

    await assertFails(manager.doc("Orders/o1").update({status: "approved", totalValue: 999}));
  });

  test("the order's own creator can mark a dispatched order delivered", async () => {
    await seed((db) => db.doc("Orders/o1").set({createdByUid: "mr1", status: "dispatched"}));
    const mr = testEnv.authenticatedContext("mr1").firestore();

    await assertSucceeds(mr.doc("Orders/o1").update({status: "delivered"}));
  });

  test("nobody else can mark someone else's order delivered", async () => {
    await seed((db) => db.doc("Orders/o1").set({createdByUid: "mr1", status: "dispatched"}));
    const other = testEnv.authenticatedContext("mr2").firestore();

    await assertFails(other.doc("Orders/o1").update({status: "delivered"}));
  });

  test("the creator cannot mark an order delivered before it's dispatched", async () => {
    await seed((db) => db.doc("Orders/o1").set({createdByUid: "mr1", status: "approved"}));
    const mr = testEnv.authenticatedContext("mr1").firestore();

    await assertFails(mr.doc("Orders/o1").update({status: "delivered"}));
  });
});

describe("DoctorVisitPlans", () => {
  test("an MR can create their own plan in draft status", async () => {
    const mr = testEnv.authenticatedContext("mr1").firestore();

    await assertSucceeds(mr.doc("DoctorVisitPlans/mr1").set({status: "draft"}));
  });

  test("an MR cannot create their own plan already marked approved", async () => {
    const mr = testEnv.authenticatedContext("mr1").firestore();

    await assertFails(mr.doc("DoctorVisitPlans/mr1").set({status: "approved"}));
  });

  test("content edits are blocked while a review is pending", async () => {
    await seed((db) => db.doc("DoctorVisitPlans/mr1").set({status: "pending", monday: []}));
    const mr = testEnv.authenticatedContext("mr1").firestore();

    await assertFails(mr.doc("DoctorVisitPlans/mr1").update({monday: ["doc1"]}));
  });

  test("a manager holding approve_requests can decide a pending plan", async () => {
    await seed((db) => db.doc("DoctorVisitPlans/mr1").set({status: "pending"}));
    await seed((db) => db.doc("Users/mr1").set({username: "mr1", reportingChainUids: ["mgr1"]}));
    await seed((db) => db.doc("Users/mgr1").set({permissions: ["approve_requests"]}));
    const manager = testEnv.authenticatedContext("mgr1").firestore();

    await assertSucceeds(
      manager.doc("DoctorVisitPlans/mr1").update({status: "approved", approvedByUid: "mgr1"})
    );
  });

  test("a manager's decision write cannot also change plan content", async () => {
    await seed((db) => db.doc("DoctorVisitPlans/mr1").set({status: "pending", monday: []}));
    await seed((db) => db.doc("Users/mr1").set({username: "mr1", reportingChainUids: ["mgr1"]}));
    await seed((db) => db.doc("Users/mgr1").set({permissions: ["approve_requests"]}));
    const manager = testEnv.authenticatedContext("mgr1").firestore();

    await assertFails(
      manager.doc("DoctorVisitPlans/mr1").update({status: "approved", monday: ["doc1"]})
    );
  });
});

describe("Agencies", () => {
  test("any signed-in user can read", async () => {
    await seed((db) => db.doc("Agencies/a1").set({name: "MedSupply Co"}));
    const mr = testEnv.authenticatedContext("mr1").firestore();

    await assertSucceeds(mr.doc("Agencies/a1").get());
  });

  test("a plain MR cannot create one directly", async () => {
    const mr = testEnv.authenticatedContext("mr1").firestore();

    await assertFails(mr.collection("Agencies").add({name: "New Agency"}));
  });

  test("an Office Admin can create one directly", async () => {
    await seed((db) => db.doc("Users/officeadmin1").set({category: "office_administration"}));
    const officeAdmin = testEnv.authenticatedContext("officeadmin1").firestore();

    await assertSucceeds(officeAdmin.collection("Agencies").add({name: "New Agency"}));
  });
});

describe("EntityChangeRequests", () => {
  test("an Office Admin can read a pending request", async () => {
    await seed((db) => db.doc("EntityChangeRequests/r1").set({requestedByUid: "mr1", status: "pending"}));
    await seed((db) => db.doc("Users/officeadmin1").set({category: "office_administration"}));
    const officeAdmin = testEnv.authenticatedContext("officeadmin1").firestore();

    await assertSucceeds(officeAdmin.doc("EntityChangeRequests/r1").get());
  });

  test("an approve_requests holder who isn't an Office Admin can also read a pending request", async () => {
    await seed((db) => db.doc("EntityChangeRequests/r1").set({requestedByUid: "mr1", status: "pending"}));
    await seed((db) => db.doc("Users/mgr1").set({permissions: ["approve_requests"]}));
    const manager = testEnv.authenticatedContext("mgr1").firestore();

    await assertSucceeds(manager.doc("EntityChangeRequests/r1").get());
  });

  test("a manager without approve_requests and not an Office Admin cannot read someone else's request", async () => {
    await seed((db) => db.doc("EntityChangeRequests/r1").set({requestedByUid: "mr1", status: "pending"}));
    await seed((db) => db.doc("Users/mgr1").set({permissions: []}));
    const manager = testEnv.authenticatedContext("mgr1").firestore();

    await assertFails(manager.doc("EntityChangeRequests/r1").get());
  });
});

describe("DoctorChangeRequests", () => {
  test("an approve_requests holder can read a pending request", async () => {
    await seed((db) => db.doc("DoctorChangeRequests/r1").set({requestedByUid: "mr1", status: "pending"}));
    await seed((db) => db.doc("Users/mgr1").set({permissions: ["approve_requests"]}));
    const manager = testEnv.authenticatedContext("mgr1").firestore();

    await assertSucceeds(manager.doc("DoctorChangeRequests/r1").get());
  });

  test("a manager without approve_requests cannot read someone else's request", async () => {
    await seed((db) => db.doc("DoctorChangeRequests/r1").set({requestedByUid: "mr1", status: "pending"}));
    await seed((db) => db.doc("Users/mgr1").set({permissions: []}));
    const manager = testEnv.authenticatedContext("mgr1").firestore();

    await assertFails(manager.doc("DoctorChangeRequests/r1").get());
  });
});

describe("DeviceTokens", () => {
  test("a user can write their own token", async () => {
    const mr = testEnv.authenticatedContext("mr1").firestore();

    await assertSucceeds(mr.doc("DeviceTokens/mr1").set({token: "abc"}));
  });

  test("a user cannot write someone else's token", async () => {
    const mr = testEnv.authenticatedContext("mr1").firestore();

    await assertFails(mr.doc("DeviceTokens/mr2").set({token: "abc"}));
  });

  test("nobody can read a device token client-side, not even the admin", async () => {
    await seed((db) => db.doc("DeviceTokens/mr1").set({token: "abc"}));
    const admin = testEnv.authenticatedContext("admin-uid", {email: ADMIN_EMAIL}).firestore();

    await assertFails(admin.doc("DeviceTokens/mr1").get());
  });
});
