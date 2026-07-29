/**
 * Seeds a full set of test data across every role and entity in the app —
 * a 5-rung designation ladder (Zonal -> Regional -> Area -> MR, plus a
 * parallel Office Admin), 6 employees spread across it, doctors, an agency,
 * a pharmacy, an order, sales targets, an expense claim, an RCPA entry, a
 * compliance log, a visit plan + visit log, and a pending doctor/entity
 * change request — so the whole app (not just the trimmed-down MR APK) can
 * be manually verified end-to-end. See docs/BUSINESS_OVERVIEW.md §17 for
 * the checklist this data is meant to exercise.
 *
 * Deliberately never touches `Products`/`Department` beyond *reading* a
 * couple of existing products to build order/RCPA line items — that catalog
 * data is real and out of scope for this script.
 *
 * Every doc this script creates is tagged `testSeed: true` (a visual marker
 * in the console) and its id is recorded in MANIFEST_PATH, which
 * `npm run test:cleanup` reads to delete exactly what this script created —
 * see cleanupTestData.ts. Run via `npm run test:seed`, using the same
 * Application Default Credentials as `firebase deploy` (same pattern as
 * migrateDesignations.ts), against whichever project the Firebase CLI is
 * currently pointed at. Refuses to run if a manifest from a previous,
 * not-yet-cleaned-up seed already exists.
 */
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
import * as fs from "fs";
import * as path from "path";

const MANIFEST_PATH = path.join(__dirname, "..", ".test-seed-manifest.json");
const PREFIX = "zz_test_";
const TEST_PASSWORD = "TestPass123!";
const TEST_EMAIL_DOMAIN = "bharathbiomedpharma.test"; // never a real, deliverable domain

interface Manifest {
  createdAt: string;
  designationIds: string[];
  employeeUids: string[];
  doctorIds: string[];
  agencyIds: string[];
  pharmacyIds: string[];
  orderIds: string[];
  salesTargetIds: string[];
  expenseClaimIds: string[];
  rcpaEntryIds: string[];
  complianceLogIds: string[];
  visitPlanMrUids: string[];
  visitLogIds: string[];
  doctorChangeRequestIds: string[];
  entityChangeRequestIds: string[];
  usageSessionIds: string[];
  reminderIds: string[];
  logins: {role: string; email: string; password: string; username: string}[];
}

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

function currentTargetPeriod(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

async function main(): Promise<void> {
  if (fs.existsSync(MANIFEST_PATH)) {
    console.error(
      `A previous test-data manifest already exists at ${MANIFEST_PATH}.\n` +
        "Run `npm run test:cleanup` first so this run doesn't orphan or double-create test data."
    );
    process.exit(1);
  }

  initializeApp();
  const firestore = getFirestore();
  const auth = getAuth();

  const manifest: Manifest = {
    createdAt: new Date().toISOString(),
    designationIds: [],
    employeeUids: [],
    doctorIds: [],
    agencyIds: [],
    pharmacyIds: [],
    orderIds: [],
    salesTargetIds: [],
    expenseClaimIds: [],
    rcpaEntryIds: [],
    complianceLogIds: [],
    visitPlanMrUids: [],
    visitLogIds: [],
    doctorChangeRequestIds: [],
    entityChangeRequestIds: [],
    usageSessionIds: [],
    reminderIds: [],
    logins: [],
  };

  // Write the (still mostly empty) manifest immediately so a crash partway
  // through still leaves a record of whatever was created up to that point
  // — flushManifest() is called after every step below.
  const flushManifest = () => fs.writeFileSync(MANIFEST_PATH, JSON.stringify(manifest, null, 2));
  flushManifest();

  try {
    // ---- 1. Designations: a full test ladder, parallel to any real ones ----
    console.log("Creating designations...");
    const designations = firestore.collection("Designations");
    const desigIdByKey = new Map<string, string>();

    const desigSeeds = [
      {
        key: "zonal",
        name: "TEST Zonal Business Manager",
        category: "field",
        hierarchyLevel: 1,
        parentKey: null as string | null,
        permissions: ["approve_orders", "approve_requests", "manage_targets", "approve_expenses", "dispatch_orders"],
      },
      {
        key: "regional",
        name: "TEST Regional Business Manager",
        category: "field",
        hierarchyLevel: 2,
        parentKey: "zonal",
        permissions: ["approve_orders", "approve_requests"],
      },
      {
        key: "area",
        name: "TEST Area Business Manager",
        category: "field",
        hierarchyLevel: 3,
        parentKey: "regional",
        permissions: ["approve_orders", "approve_requests", "manage_agencies"],
      },
      {
        key: "officeadmin",
        name: "TEST Office Admin",
        category: "office_administration",
        hierarchyLevel: 1,
        parentKey: null,
        permissions: ["approve_requests"],
      },
      {
        key: "mr",
        name: "TEST Medical Representative",
        category: "field",
        hierarchyLevel: 5,
        parentKey: "area",
        permissions: ["create_orders"],
      },
    ];

    for (const seed of desigSeeds) {
      const ref = await designations.add({
        name: seed.name,
        category: seed.category,
        hierarchyLevel: seed.hierarchyLevel,
        permissions: seed.permissions,
        parentDesignationId: null,
        testSeed: true,
      });
      desigIdByKey.set(seed.key, ref.id);
      manifest.designationIds.push(ref.id);
    }
    for (const seed of desigSeeds) {
      if (!seed.parentKey) continue;
      const id = desigIdByKey.get(seed.key)!;
      await designations.doc(id).set({parentDesignationId: desigIdByKey.get(seed.parentKey)!}, {merge: true});
    }
    flushManifest();
    console.log(`  ${desigSeeds.length} designations created.`);

    // ---- 2. Employees: created top-down so each one's manager already ----
    // ---- has a uid to compute reportingChainUids/permissions locally. ----
    console.log("Creating employees...");

    interface EmployeeSeed {
      key: string;
      username: string;
      firstName: string;
      lastName: string;
      designationKey: string;
      managerKey: string | null;
      profileCompleted: boolean;
    }

    const employeeSeeds: EmployeeSeed[] = [
      {key: "zbm", username: `${PREFIX}zbm`, firstName: "Zonal", lastName: "TestUser", designationKey: "zonal", managerKey: null, profileCompleted: true},
      {key: "rbm", username: `${PREFIX}rbm`, firstName: "Regional", lastName: "TestUser", designationKey: "regional", managerKey: "zbm", profileCompleted: true},
      {key: "abm", username: `${PREFIX}abm`, firstName: "Area", lastName: "TestUser", designationKey: "area", managerKey: "rbm", profileCompleted: true},
      {key: "officeadmin", username: `${PREFIX}officeadmin`, firstName: "Office", lastName: "TestAdmin", designationKey: "officeadmin", managerKey: null, profileCompleted: true},
      // profileCompleted: false on mr1 on purpose, to exercise the mandatory
      // first-login "Complete Your Profile" step at least once.
      {key: "mr1", username: `${PREFIX}mr1`, firstName: "Mr", lastName: "TestOne", designationKey: "mr", managerKey: "abm", profileCompleted: false},
      {key: "mr2", username: `${PREFIX}mr2`, firstName: "Mr", lastName: "TestTwo", designationKey: "mr", managerKey: "abm", profileCompleted: true},
    ];

    const uidByKey = new Map<string, string>();
    const chainByKey = new Map<string, string[]>();
    const roleLabelByKey = new Map(desigSeeds.map((d) => [d.key, d.name]));

    for (const seed of employeeSeeds) {
      const email = `${seed.username}@${TEST_EMAIL_DOMAIN}`;
      const displayName = `${seed.firstName} ${seed.lastName}`;
      const designationId = desigIdByKey.get(seed.designationKey)!;
      const desig = desigSeeds.find((d) => d.key === seed.designationKey)!;
      const managerUid = seed.managerKey ? uidByKey.get(seed.managerKey)! : null;
      const chain = managerUid ? [managerUid, ...(chainByKey.get(seed.managerKey!) ?? [])] : [];

      const userRecord = await auth.createUser({email, password: TEST_PASSWORD, displayName, emailVerified: true});
      await auth.setCustomUserClaims(userRecord.uid, {role: "mr"});
      await firestore.collection("Users").doc(userRecord.uid).set({
        username: seed.username,
        firstName: seed.firstName,
        lastName: seed.lastName,
        displayName,
        designation: desig.name,
        areaName: "Test Area",
        mobileNumber: null,
        photoUrl: null,
        email,
        dateOfBirth: null,
        designationId,
        managerId: managerUid,
        role: "mr",
        disabled: false,
        profileCompleted: seed.profileCompleted,
        reportingChainUids: chain,
        category: desig.category,
        hierarchyLevel: desig.hierarchyLevel,
        permissions: desig.permissions,
        createdAt: FieldValue.serverTimestamp(),
        createdBy: "seedTestData-script",
        testSeed: true,
      });

      uidByKey.set(seed.key, userRecord.uid);
      chainByKey.set(seed.key, chain);
      manifest.employeeUids.push(userRecord.uid);
      manifest.logins.push({
        role: roleLabelByKey.get(seed.designationKey) ?? seed.designationKey,
        email,
        password: TEST_PASSWORD,
        username: seed.username,
      });
      flushManifest();
      console.log(`  Created ${seed.key} (${displayName}) uid=${userRecord.uid}`);
    }

    const mr1Uid = uidByKey.get("mr1")!;
    const mr1Name = "Mr TestOne";
    const mr2Uid = uidByKey.get("mr2")!;
    const mr2Name = "Mr TestTwo";
    const abmUid = uidByKey.get("abm")!;
    const officeAdminUid = uidByKey.get("officeadmin")!;

    // ---- 3. Doctors ----
    console.log("Creating doctors...");
    const doctors = firestore.collection("Doctors");
    const doc1 = await doctors.add({
      name: "Dr. Test One",
      specialisation: "General Physician",
      hospitalName: "Test City Hospital",
      locationAddress: "123 Test Street, Test City",
      latitude: null,
      longitude: null,
      googleMapsLink: null,
      doctorPhotoUrls: [],
      hospitalPhotoUrls: [],
      dateOfBirth: null,
      marriageAnniversary: null,
      assignedMrUid: mr1Uid,
      assignedMrName: mr1Name,
      createdByUid: "seedTestData-script",
      createdByName: "Test Seed Script",
      createdAt: FieldValue.serverTimestamp(),
      testSeed: true,
    });
    const doc2 = await doctors.add({
      name: "Dr. Test Two",
      specialisation: "Pediatrics",
      hospitalName: "Test Children's Clinic",
      locationAddress: "456 Test Avenue, Test City",
      latitude: null,
      longitude: null,
      googleMapsLink: null,
      doctorPhotoUrls: [],
      hospitalPhotoUrls: [],
      dateOfBirth: null,
      marriageAnniversary: null,
      assignedMrUid: mr2Uid,
      assignedMrName: mr2Name,
      createdByUid: "seedTestData-script",
      createdByName: "Test Seed Script",
      createdAt: FieldValue.serverTimestamp(),
      testSeed: true,
    });
    const doc3 = await doctors.add({
      name: "Dr. Test Unassigned",
      specialisation: "Orthopedics",
      hospitalName: "Test Ortho Center",
      locationAddress: "789 Test Road, Test City",
      latitude: null,
      longitude: null,
      googleMapsLink: null,
      doctorPhotoUrls: [],
      hospitalPhotoUrls: [],
      dateOfBirth: null,
      marriageAnniversary: null,
      assignedMrUid: null,
      assignedMrName: null,
      createdByUid: "seedTestData-script",
      createdByName: "Test Seed Script",
      createdAt: FieldValue.serverTimestamp(),
      testSeed: true,
    });
    manifest.doctorIds.push(doc1.id, doc2.id, doc3.id);
    flushManifest();
    console.log(`  3 doctors created (2 assigned, 1 unassigned).`);

    // ---- 4. Agency + Pharmacy ----
    console.log("Creating agency and pharmacy...");
    const agencyRef = await firestore.collection("Agencies").add({
      name: "TEST Agency Distributors",
      contactPerson: "Test Contact",
      phone: "9999900000",
      address: "1 Test Industrial Area",
      latitude: null,
      longitude: null,
      gstNumber: "TESTGST0000",
      active: true,
      createdByUid: officeAdminUid,
      createdByName: "Office TestAdmin",
      createdAt: FieldValue.serverTimestamp(),
      testSeed: true,
    });
    const pharmacyRef = await firestore.collection("Pharmacies").add({
      name: "TEST City Pharmacy",
      address: "2 Test Market Road",
      latitude: null,
      longitude: null,
      phone: "9999900001",
      linkedDoctorIds: [doc1.id],
      assignedMrUid: mr1Uid,
      assignedMrName: mr1Name,
      active: true,
      createdByUid: officeAdminUid,
      createdByName: "Office TestAdmin",
      createdAt: FieldValue.serverTimestamp(),
      testSeed: true,
    });
    manifest.agencyIds.push(agencyRef.id);
    manifest.pharmacyIds.push(pharmacyRef.id);
    flushManifest();
    console.log("  1 agency + 1 pharmacy created.");

    // ---- 5. Read (never write) a couple of real products for line items ----
    console.log("Reading existing products for order/RCPA line items (read-only)...");
    const productsSnap = await firestore.collection("Products").limit(2).get();
    const products = productsSnap.docs.map((d) => ({id: d.id, name: (d.data().name as string) ?? "Unnamed", unitPrice: (d.data().unitPrice as number) ?? 0}));
    if (products.length === 0) {
      console.warn("  No products found — skipping the test Order and RCPA own-brand counts.");
    } else {
      console.log(`  Using ${products.length} existing product(s): ${products.map((p) => p.name).join(", ")}`);
    }

    // ---- 6. Order (pending, against the test agency) ----
    if (products.length > 0) {
      console.log("Creating order...");
      const items = products.map((p) => ({productId: p.id, productName: p.name, quantity: 5, unitPrice: p.unitPrice || 100}));
      const totalValue = items.reduce((sum, i) => sum + i.quantity * i.unitPrice, 0);
      const orderRef = await firestore.collection("Orders").add({
        agencyId: agencyRef.id,
        agencyName: "TEST Agency Distributors",
        createdByUid: mr1Uid,
        createdByName: mr1Name,
        items,
        totalValue,
        status: "pending",
        createdAt: FieldValue.serverTimestamp(),
        testSeed: true,
      });
      manifest.orderIds.push(orderRef.id);
      flushManifest();
      console.log(`  1 order created (pending, value ${totalValue}).`);
    }

    // ---- 7. Sales targets for both MRs, current month ----
    console.log("Creating sales targets...");
    const period = currentTargetPeriod();
    for (const [uid, value] of [[mr1Uid, 50000], [mr2Uid, 40000]] as [string, number][]) {
      const targetId = `${uid}_${period}`;
      await firestore.collection("SalesTargets").doc(targetId).set({
        employeeUid: uid,
        period,
        targetValue: value,
        createdByUid: abmUid,
        createdAt: FieldValue.serverTimestamp(),
        testSeed: true,
      });
      manifest.salesTargetIds.push(targetId);
    }
    flushManifest();
    console.log(`  2 sales targets created for period ${period}.`);

    // ---- 8. Expense claim (pending) ----
    console.log("Creating expense claim...");
    const claimRef = await firestore.collection("ExpenseClaims").add({
      mrUid: mr1Uid,
      mrName: mr1Name,
      category: "travel",
      claimDate: today(),
      amount: 750,
      description: "Test travel claim - client visit",
      receiptPhotoUrl: null,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      testSeed: true,
    });
    manifest.expenseClaimIds.push(claimRef.id);
    flushManifest();
    console.log("  1 expense claim created (pending).");

    // ---- 9. RCPA entry ----
    console.log("Creating RCPA entry...");
    const rcpaRef = await firestore.collection("RcpaEntries").add({
      mrUid: mr1Uid,
      pharmacyId: pharmacyRef.id,
      pharmacyName: "TEST City Pharmacy",
      auditDate: today(),
      ownBrandCounts: products.map((p) => ({productId: p.id, productName: p.name, count: 12})),
      competitorCounts: [{brandName: "Test Competitor Brand", count: 5}],
      notes: "Test RCPA entry",
      latitude: null,
      longitude: null,
      createdAt: FieldValue.serverTimestamp(),
      testSeed: true,
    });
    manifest.rcpaEntryIds.push(rcpaRef.id);
    flushManifest();
    console.log("  1 RCPA entry created.");

    // ---- 10. Compliance log ----
    console.log("Creating compliance log...");
    const complianceRef = await firestore.collection("ComplianceLogs").add({
      mrUid: mr1Uid,
      mrName: mr1Name,
      doctorId: doc1.id,
      doctorName: "Dr. Test One",
      category: "sample",
      description: "Test product sample",
      value: 250,
      logDate: today(),
      createdAt: FieldValue.serverTimestamp(),
      testSeed: true,
    });
    manifest.complianceLogIds.push(complianceRef.id);
    flushManifest();
    console.log("  1 compliance log created.");

    // ---- 11. Visit plan (submitted) + visit log ----
    console.log("Creating visit plan and visit log...");
    await firestore.collection("DoctorVisitPlans").doc(mr1Uid).set({
      monday: [doc1.id],
      tuesday: [],
      wednesday: [],
      thursday: [],
      friday: [],
      saturday: [],
      sunday: [],
      status: "pending",
      approvedByUid: null,
      approvedAt: null,
      rejectedReason: null,
      testSeed: true,
    });
    manifest.visitPlanMrUids.push(mr1Uid);
    const visitLogRef = await firestore.collection("DoctorVisitLogs").add({
      mrUid: mr1Uid,
      doctorId: doc1.id,
      doctorName: "Dr. Test One",
      visitDate: today(),
      visited: true,
      feedback: "Test feedback - doctor was receptive",
      latitude: null,
      longitude: null,
      samplesGiven: {},
      createdAt: FieldValue.serverTimestamp(),
      testSeed: true,
    });
    manifest.visitLogIds.push(visitLogRef.id);
    flushManifest();
    console.log("  1 visit plan (pending approval) + 1 visit log created.");

    // ---- 12. Pending doctor + entity change requests (for approval testing) ----
    console.log("Creating pending change requests...");
    const doctorRequestRef = await firestore.collection("DoctorChangeRequests").add({
      type: "create",
      doctorId: null,
      proposedData: {
        name: "Dr. Test Proposed",
        specialisation: "Cardiology",
        hospitalName: "Test Heart Clinic",
        locationAddress: "321 Test Blvd",
        doctorPhotoUrls: [],
        hospitalPhotoUrls: [],
      },
      requestedByUid: mr2Uid,
      requestedByName: mr2Name,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      testSeed: true,
    });
    const entityRequestRef = await firestore.collection("EntityChangeRequests").add({
      entityType: "pharmacy",
      type: "create",
      entityId: null,
      proposedData: {name: "TEST Proposed Pharmacy", address: "654 Test Lane", active: true},
      requestedByUid: mr2Uid,
      requestedByName: mr2Name,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      testSeed: true,
    });
    manifest.doctorChangeRequestIds.push(doctorRequestRef.id);
    manifest.entityChangeRequestIds.push(entityRequestRef.id);
    flushManifest();
    console.log("  1 doctor change request + 1 entity change request created (both pending).");

    // ---- 13. A usage session + a reminder ----
    console.log("Creating usage session and reminder...");
    const now = Date.now();
    const sessionRef = await firestore.collection("UsageSessions").add({
      employeeUid: mr1Uid,
      username: `${PREFIX}mr1`,
      openedAt: new Date(now - 60 * 60 * 1000),
      closedAt: new Date(now),
      durationSeconds: 3600,
      latitude: null,
      longitude: null,
      uploadedAt: FieldValue.serverTimestamp(),
      testSeed: true,
    });
    manifest.usageSessionIds.push(sessionRef.id);
    const reminderRef = await firestore.collection("Reminders").add({
      ownerUid: mr1Uid,
      ownerName: mr1Name,
      createdByUid: officeAdminUid,
      createdByName: "Office TestAdmin",
      title: "TEST: Follow up with Dr Test One",
      note: "Seeded test reminder",
      dueAt: new Date(now + 24 * 60 * 60 * 1000),
      completed: false,
      notified: false,
      createdAt: FieldValue.serverTimestamp(),
      testSeed: true,
    });
    manifest.reminderIds.push(reminderRef.id);
    flushManifest();
    console.log("  1 usage session + 1 reminder created.");

    console.log("\nDone. Test accounts (log in with the FULL EMAIL below, not the username — see note):\n");
    for (const login of manifest.logins) {
      console.log(`  ${login.role.padEnd(28)} email=${login.email.padEnd(38)} password=${login.password}`);
    }
    console.log(
      "\nNote: type the full email (with @) into the login screen. A bare username there resolves to a" +
        " different, legacy synthetic-domain address these test accounts don't use.\n" +
        `Manifest written to ${MANIFEST_PATH} — run \`npm run test:cleanup\` when done verifying to remove all of this.`
    );
  } catch (error) {
    console.error("\nseedTestData failed partway through. What was created so far is recorded in the manifest at", MANIFEST_PATH);
    console.error("Run `npm run test:cleanup` to remove it, then re-run this script.");
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("seedTestData failed:", error);
    process.exit(1);
  });
