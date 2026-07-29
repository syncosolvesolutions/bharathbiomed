/**
 * Seeds a realistic, fully-populated test tenant — big enough to look like
 * six months of real usage, not a one-of-everything smoke test:
 *
 *   - Org tree (doubles at every rung, so every designation has >=2 people
 *     and every manager has exactly 2 direct reports, all the way down):
 *       2 Office Admins (parallel ladder)
 *       2 Zonal Business Managers (ZBM)
 *         -> 2 Regional Business Managers (RBM) each  = 4 RBM
 *           -> 2 Area Business Managers (ABM) each    = 8 ABM  (= 8 "areas")
 *             -> 2 Medical Representatives (MR) each  = 16 MR
 *   - 3 doctors per MR (48 doctors total).
 *   - 4 pharmacies per MR (64 total): 1 standalone (no linked doctor) plus
 *     one linked to each of that MR's 3 doctors.
 *   - 1 agency per area/ABM (8 total).
 *   - Everything else (orders, sales targets, expense claims, RCPA entries,
 *     compliance logs, visit plans/logs, change requests, usage sessions,
 *     reminders) is seeded with >=10 documents each, dates spread evenly
 *     across the last ~6 months, deliberately cycling through every
 *     status/enum value that collection has so no UI filter or admin queue
 *     is ever empty. See docs/BUSINESS_OVERVIEW.md §17 for the manual
 *     checklist this data is meant to exercise.
 *
 * Deliberately never touches `Products`/`Department` beyond *reading* a
 * few existing products to build order/RCPA line items — that catalog
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
 *
 * Also writes every login (real-world name, designation abbreviation,
 * manager, area, username/email/password) to a single Excel workbook at
 * CREDENTIALS_XLSX_PATH so the whole roster can be handed out for manual
 * testing without copy-pasting 32 lines out of a terminal.
 */
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
import * as fs from "fs";
import * as path from "path";
import * as ExcelJS from "exceljs";

const MANIFEST_PATH = path.join(__dirname, "..", ".test-seed-manifest.json");
const CREDENTIALS_XLSX_PATH = path.join(__dirname, "..", ".test-seed-credentials.xlsx");
const PREFIX = "zz_test_";
const TEST_PASSWORD = "TestPass123!";
const TEST_EMAIL_DOMAIN = "bharathbiomedpharma.test"; // never a real, deliverable domain

// ---- Org tree shape: every level below doubles, so every designation ends
// ---- up with >=2 people and every manager has exactly 2 direct reports.
const OFFICE_ADMIN_COUNT = 2;
const ZBM_COUNT = 2;
const RBM_PER_ZBM = 2;
const ABM_PER_RBM = 2;
const MR_PER_ABM = 2;
const DOCTORS_PER_MR = 3;

const DESIG_ABBR: Record<string, string> = {
  zbm: "ZBM",
  rbm: "RBM",
  abm: "ABM",
  mr: "MR",
  officeadmin: "OA",
};

// 32 distinct (firstName, lastName) pairs — enough for the whole tree
// (2 + 2 + 4 + 8 + 16 = 32) with no two employees sharing a full name.
const NAME_POOL: [string, string][] = [
  ["Rajesh", "Kumar"], ["Anita", "Sharma"], ["Vikram", "Singh"], ["Sunita", "Reddy"],
  ["Manoj", "Nair"], ["Deepa", "Verma"], ["Ravi", "Gupta"], ["Kavita", "Iyer"],
  ["Arun", "Patel"], ["Meena", "Rao"], ["Sanjay", "Menon"], ["Pooja", "Chauhan"],
  ["Vijay", "Joshi"], ["Neha", "Pillai"], ["Ashok", "Desai"], ["Rekha", "Mehta"],
  ["Ramesh", "Choudhury"], ["Geeta", "Naidu"], ["Prakash", "Bose"], ["Lakshmi", "Bhat"],
  ["Naveen", "Kulkarni"], ["Shanti", "Shetty"], ["Dinesh", "Agarwal"], ["Anjali", "Trivedi"],
  ["Mahesh", "Pandey"], ["Sarita", "Yadav"], ["Rajendra", "Chatterjee"], ["Nisha", "Bhatt"],
  ["Kiran", "Sinha"], ["Amit", "Ghosh"], ["Priya", "Das"], ["Suresh", "Malhotra"],
];
let nameCursor = 0;
function nextName(): {firstName: string; lastName: string} {
  const [firstName, lastName] = NAME_POOL[nameCursor % NAME_POOL.length];
  nameCursor++;
  return {firstName, lastName};
}

interface LoginRecord {
  role: string;
  abbr: string;
  fullName: string;
  managerName: string;
  areaName: string;
  email: string;
  password: string;
  username: string;
}

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
  logins: LoginRecord[];
}

function isoDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

function periodMonthsAgo(monthsAgo: number): string {
  const d = new Date();
  d.setDate(1); // pin to the 1st first so setMonth() can't roll over into a different day-of-month
  d.setMonth(d.getMonth() - monthsAgo);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

function daysAgo(count: number): Date {
  const d = new Date();
  d.setDate(d.getDate() - count);
  return d;
}

/** Spreads `total` items evenly across the last ~6 months, oldest at index 0. */
function spreadOverSixMonths(index: number, total: number): Date {
  const spanDays = 178;
  const progress = total <= 1 ? 1 : index / (total - 1);
  return daysAgo(Math.round(spanDays * (1 - progress)));
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

  const flushManifest = () => fs.writeFileSync(MANIFEST_PATH, JSON.stringify(manifest, null, 2));
  flushManifest();

  try {
    // ---- 1. Designations: a full test ladder, parallel to any real ones ----
    console.log("Creating designations...");
    const designations = firestore.collection("Designations");
    const desigIdByKey = new Map<string, string>();

    const desigSeeds = [
      {
        key: "zbm",
        name: "TEST Zonal Business Manager",
        category: "field",
        hierarchyLevel: 1,
        parentKey: null as string | null,
        permissions: ["approve_orders", "approve_requests", "manage_targets", "approve_expenses", "dispatch_orders"],
      },
      {
        key: "rbm",
        name: "TEST Regional Business Manager",
        category: "field",
        hierarchyLevel: 2,
        parentKey: "zbm",
        permissions: ["approve_orders", "approve_requests"],
      },
      {
        key: "abm",
        name: "TEST Area Business Manager",
        category: "field",
        hierarchyLevel: 3,
        parentKey: "rbm",
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
        parentKey: "abm",
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

    // ---- 2. Build the employee tree (top-down, so parents always exist ----
    // ---- with a uid before their children are generated/created). ----
    interface EmployeeSeed {
      key: string;
      username: string;
      designationKey: string;
      managerKey: string | null;
      areaName: string | null;
      areaIndex: number | null;
      profileCompleted: boolean;
    }

    const employeeSeeds: EmployeeSeed[] = [];

    for (let i = 1; i <= OFFICE_ADMIN_COUNT; i++) {
      employeeSeeds.push({
        key: `oa${i}`, username: `${PREFIX}oa${i}`, designationKey: "officeadmin",
        managerKey: null, areaName: null, areaIndex: null, profileCompleted: true,
      });
    }

    for (let z = 1; z <= ZBM_COUNT; z++) {
      employeeSeeds.push({
        key: `zbm${z}`, username: `${PREFIX}zbm${z}`, designationKey: "zbm",
        managerKey: null, areaName: null, areaIndex: null, profileCompleted: true,
      });
    }

    const rbmCount = ZBM_COUNT * RBM_PER_ZBM;
    for (let r = 1; r <= rbmCount; r++) {
      const parentZ = Math.ceil(r / RBM_PER_ZBM);
      employeeSeeds.push({
        key: `rbm${r}`, username: `${PREFIX}rbm${r}`, designationKey: "rbm",
        managerKey: `zbm${parentZ}`, areaName: null, areaIndex: null, profileCompleted: true,
      });
    }

    const abmCount = rbmCount * ABM_PER_RBM;
    for (let a = 1; a <= abmCount; a++) {
      const parentR = Math.ceil(a / ABM_PER_RBM);
      employeeSeeds.push({
        key: `abm${a}`, username: `${PREFIX}abm${a}`, designationKey: "abm",
        managerKey: `rbm${parentR}`, areaName: `Test Area ${a}`, areaIndex: a, profileCompleted: true,
      });
    }

    const mrCount = abmCount * MR_PER_ABM;
    for (let m = 1; m <= mrCount; m++) {
      const parentA = Math.ceil(m / MR_PER_ABM);
      employeeSeeds.push({
        key: `mr${m}`, username: `${PREFIX}mr${m}`, designationKey: "mr",
        managerKey: `abm${parentA}`, areaName: `Test Area ${parentA}`, areaIndex: parentA,
        // Keep exactly one intentionally-incomplete profile to exercise the
        // mandatory first-login "Complete Your Profile" step at least once.
        profileCompleted: m !== 1,
      });
    }

    console.log(
      `Creating ${employeeSeeds.length} employees ` +
        `(${OFFICE_ADMIN_COUNT} Office Admin, ${ZBM_COUNT} ZBM, ${rbmCount} RBM, ${abmCount} ABM, ${mrCount} MR)...`
    );

    const desigByKey = new Map(desigSeeds.map((d) => [d.key, d]));
    const uidByKey = new Map<string, string>();
    const chainByKey = new Map<string, string[]>();
    const nameByKey = new Map<string, string>();

    for (const seed of employeeSeeds) {
      const {firstName, lastName} = nextName();
      const displayName = `${firstName} ${lastName}`;
      const email = `${seed.username}@${TEST_EMAIL_DOMAIN}`;
      const designationId = desigIdByKey.get(seed.designationKey)!;
      const desig = desigByKey.get(seed.designationKey)!;
      const managerUid = seed.managerKey ? uidByKey.get(seed.managerKey)! : null;
      const chain = managerUid ? [managerUid, ...(chainByKey.get(seed.managerKey!) ?? [])] : [];

      const userRecord = await auth.createUser({email, password: TEST_PASSWORD, displayName, emailVerified: true});
      await auth.setCustomUserClaims(userRecord.uid, {role: "mr"});
      await firestore.collection("Users").doc(userRecord.uid).set({
        username: seed.username,
        firstName,
        lastName,
        displayName,
        designation: desig.name,
        areaName: seed.areaName ?? "Head Office",
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
      nameByKey.set(seed.key, displayName);
      manifest.employeeUids.push(userRecord.uid);
      manifest.logins.push({
        role: desig.name,
        abbr: DESIG_ABBR[seed.designationKey],
        fullName: displayName,
        managerName: seed.managerKey ? nameByKey.get(seed.managerKey)! : "(none)",
        areaName: seed.areaName ?? "Head Office",
        email,
        password: TEST_PASSWORD,
        username: seed.username,
      });
      flushManifest();
    }
    console.log(`  ${employeeSeeds.length} employees created.`);

    const officeAdminEntries = employeeSeeds
      .filter((s) => s.designationKey === "officeadmin")
      .map((s) => ({uid: uidByKey.get(s.key)!, name: nameByKey.get(s.key)!}));
    const abmEntries = employeeSeeds
      .filter((s) => s.designationKey === "abm")
      .map((s) => ({key: s.key, uid: uidByKey.get(s.key)!, name: nameByKey.get(s.key)!, areaIndex: s.areaIndex!, areaName: s.areaName!}));
    const mrEntries = employeeSeeds
      .filter((s) => s.designationKey === "mr")
      .map((s) => ({
        key: s.key,
        uid: uidByKey.get(s.key)!,
        name: nameByKey.get(s.key)!,
        username: s.username,
        areaIndex: s.areaIndex!,
        areaName: s.areaName!,
      }));

    // ---- 3. Doctors: 3 per MR ----
    console.log(`Creating doctors (${DOCTORS_PER_MR} per MR)...`);
    const doctors = firestore.collection("Doctors");
    const SPECIALISATIONS = ["General Physician", "Pediatrics", "Orthopedics", "Cardiology", "Dermatology", "ENT", "Gynaecology", "Neurology"];
    const doctorIdsByMr = new Map<string, string[]>();
    const doctorNameById = new Map<string, string>();
    let doctorCounter = 0;
    for (const mr of mrEntries) {
      const ids: string[] = [];
      for (let d = 1; d <= DOCTORS_PER_MR; d++) {
        doctorCounter++;
        const name = `Dr. Test ${doctorCounter}`;
        const ref = await doctors.add({
          name,
          specialisation: SPECIALISATIONS[doctorCounter % SPECIALISATIONS.length],
          hospitalName: `Test Hospital ${doctorCounter}`,
          locationAddress: `${doctorCounter} Test Street, ${mr.areaName}`,
          latitude: null,
          longitude: null,
          googleMapsLink: null,
          doctorPhotoUrls: [],
          hospitalPhotoUrls: [],
          dateOfBirth: null,
          marriageAnniversary: null,
          assignedMrUid: mr.uid,
          assignedMrName: mr.name,
          createdByUid: "seedTestData-script",
          createdByName: "Test Seed Script",
          createdAt: FieldValue.serverTimestamp(),
          testSeed: true,
        });
        ids.push(ref.id);
        doctorNameById.set(ref.id, name);
        manifest.doctorIds.push(ref.id);
        flushManifest();
      }
      doctorIdsByMr.set(mr.key, ids);
    }
    console.log(`  ${doctorCounter} doctors created.`);

    // ---- 4. Pharmacies: 1 standalone + 1 per doctor, per MR ----
    console.log("Creating pharmacies (1 standalone + 1 per doctor, per MR)...");
    const pharmacies = firestore.collection("Pharmacies");
    const pharmacyIdsByMr = new Map<string, string[]>();
    const pharmacyNameById = new Map<string, string>();
    let pharmacyCounter = 0;
    for (const mr of mrEntries) {
      const ids: string[] = [];
      const creator = officeAdminEntries[pharmacyCounter % officeAdminEntries.length];

      pharmacyCounter++;
      const standaloneName = `TEST Standalone Pharmacy ${pharmacyCounter}`;
      const standaloneRef = await pharmacies.add({
        name: standaloneName,
        address: `${pharmacyCounter} Test Market Road, ${mr.areaName}`,
        latitude: null,
        longitude: null,
        phone: `99999${String(10000 + pharmacyCounter).slice(-5)}`,
        linkedDoctorIds: [],
        assignedMrUid: mr.uid,
        assignedMrName: mr.name,
        active: true,
        createdByUid: creator.uid,
        createdByName: creator.name,
        createdAt: FieldValue.serverTimestamp(),
        testSeed: true,
      });
      ids.push(standaloneRef.id);
      pharmacyNameById.set(standaloneRef.id, standaloneName);
      manifest.pharmacyIds.push(standaloneRef.id);
      flushManifest();

      for (const doctorId of doctorIdsByMr.get(mr.key)!) {
        pharmacyCounter++;
        const linkedName = `TEST Pharmacy ${pharmacyCounter} (near ${doctorNameById.get(doctorId)})`;
        const linkedRef = await pharmacies.add({
          name: linkedName,
          address: `${pharmacyCounter} Test Market Road, ${mr.areaName}`,
          latitude: null,
          longitude: null,
          phone: `99999${String(10000 + pharmacyCounter).slice(-5)}`,
          linkedDoctorIds: [doctorId],
          assignedMrUid: mr.uid,
          assignedMrName: mr.name,
          active: true,
          createdByUid: creator.uid,
          createdByName: creator.name,
          createdAt: FieldValue.serverTimestamp(),
          testSeed: true,
        });
        ids.push(linkedRef.id);
        pharmacyNameById.set(linkedRef.id, linkedName);
        manifest.pharmacyIds.push(linkedRef.id);
        flushManifest();
      }
      pharmacyIdsByMr.set(mr.key, ids);
    }
    console.log(`  ${pharmacyCounter} pharmacies created.`);

    // ---- 5. Agencies: 1 per area/ABM ----
    console.log("Creating agencies (1 per area)...");
    const agencies = firestore.collection("Agencies");
    const agencyIdByAreaIndex = new Map<number, string>();
    const agencyNameByAreaIndex = new Map<number, string>();
    for (const abm of abmEntries) {
      const name = `TEST Agency - ${abm.areaName}`;
      const creator = officeAdminEntries[abm.areaIndex % officeAdminEntries.length];
      const ref = await agencies.add({
        name,
        contactPerson: `${abm.name} (Area Contact)`,
        phone: `98${String(1000000 + abm.areaIndex).slice(-8)}`,
        address: `Industrial Area, ${abm.areaName}`,
        latitude: null,
        longitude: null,
        gstNumber: `TESTGST${String(abm.areaIndex).padStart(4, "0")}`,
        active: true,
        createdByUid: creator.uid,
        createdByName: creator.name,
        createdAt: FieldValue.serverTimestamp(),
        testSeed: true,
      });
      agencyIdByAreaIndex.set(abm.areaIndex, ref.id);
      agencyNameByAreaIndex.set(abm.areaIndex, name);
      manifest.agencyIds.push(ref.id);
      flushManifest();
    }
    console.log(`  ${abmEntries.length} agencies created.`);

    // ---- 6. Read (never write) a few real products for line items ----
    console.log("Reading existing products for order/RCPA line items (read-only)...");
    const productsSnap = await firestore.collection("Products").limit(5).get();
    const products = productsSnap.docs.map((d) => ({id: d.id, name: (d.data().name as string) ?? "Unnamed", unitPrice: (d.data().unitPrice as number) ?? 0}));
    if (products.length === 0) {
      console.warn("  No products found — skipping Orders and RCPA own-brand counts.");
    } else {
      console.log(`  Using ${products.length} existing product(s): ${products.map((p) => p.name).join(", ")}`);
    }

    // ---- 7. Orders: >=10, every status represented, spread over 6 months ----
    if (products.length > 0) {
      console.log("Creating orders...");
      const ORDER_STATUSES = ["pending", "approved", "dispatched", "delivered", "rejected"];
      const ORDER_COUNT = 20;
      for (let i = 0; i < ORDER_COUNT; i++) {
        const mr = mrEntries[i % mrEntries.length];
        const agencyId = agencyIdByAreaIndex.get(mr.areaIndex)!;
        const agencyName = agencyNameByAreaIndex.get(mr.areaIndex)!;
        const status = ORDER_STATUSES[i % ORDER_STATUSES.length];
        const items = products.map((p, idx) => ({productId: p.id, productName: p.name, quantity: 3 + ((i + idx) % 5), unitPrice: p.unitPrice || 100}));
        const totalValue = items.reduce((sum, item) => sum + item.quantity * item.unitPrice, 0);
        const ref = await firestore.collection("Orders").add({
          agencyId,
          agencyName,
          createdByUid: mr.uid,
          createdByName: mr.name,
          items,
          totalValue,
          status,
          createdAt: spreadOverSixMonths(i, ORDER_COUNT),
          testSeed: true,
        });
        manifest.orderIds.push(ref.id);
        flushManifest();
      }
      console.log(`  ${ORDER_COUNT} orders created, covering every status.`);
    }

    // ---- 8. Sales targets: 6 months of history for every MR ----
    console.log("Creating sales targets (6 months per MR)...");
    let salesTargetCount = 0;
    for (const mr of mrEntries) {
      const abmUid = chainByKey.get(mr.key)![0];
      for (let monthsAgo = 0; monthsAgo < 6; monthsAgo++) {
        const period = periodMonthsAgo(monthsAgo);
        const targetId = `${mr.uid}_${period}`;
        await firestore.collection("SalesTargets").doc(targetId).set({
          employeeUid: mr.uid,
          period,
          targetValue: 30000 + mr.areaIndex * 1000 + monthsAgo * 500,
          createdByUid: abmUid,
          createdAt: FieldValue.serverTimestamp(),
          testSeed: true,
        });
        manifest.salesTargetIds.push(targetId);
        salesTargetCount++;
        flushManifest();
      }
    }
    console.log(`  ${salesTargetCount} sales targets created.`);

    // ---- 9. Expense claims: >=10, every category + status represented ----
    console.log("Creating expense claims...");
    const EXPENSE_CATEGORIES = ["travel", "dailyAllowance", "lodging", "other"];
    const EXPENSE_STATUSES = ["pending", "approved", "rejected"];
    const EXPENSE_COUNT = 15;
    for (let i = 0; i < EXPENSE_COUNT; i++) {
      const mr = mrEntries[i % mrEntries.length];
      const category = EXPENSE_CATEGORIES[i % EXPENSE_CATEGORIES.length];
      const status = EXPENSE_STATUSES[i % EXPENSE_STATUSES.length];
      const claimDate = spreadOverSixMonths(i, EXPENSE_COUNT);
      const ref = await firestore.collection("ExpenseClaims").add({
        mrUid: mr.uid,
        mrName: mr.name,
        category,
        claimDate: isoDate(claimDate),
        amount: 300 + ((i * 47) % 900),
        description: `Test ${category} claim #${i + 1}`,
        receiptPhotoUrl: null,
        status,
        createdAt: claimDate,
        testSeed: true,
      });
      manifest.expenseClaimIds.push(ref.id);
      flushManifest();
    }
    console.log(`  ${EXPENSE_COUNT} expense claims created, covering every category and status.`);

    // ---- 10. RCPA entries: >=10 ----
    if (products.length > 0) {
      console.log("Creating RCPA entries...");
      const RCPA_COUNT = 15;
      for (let i = 0; i < RCPA_COUNT; i++) {
        const mr = mrEntries[i % mrEntries.length];
        const pharmacyIds = pharmacyIdsByMr.get(mr.key)!;
        const pharmacyId = pharmacyIds[i % pharmacyIds.length];
        const auditDate = spreadOverSixMonths(i, RCPA_COUNT);
        const ref = await firestore.collection("RcpaEntries").add({
          mrUid: mr.uid,
          pharmacyId,
          pharmacyName: pharmacyNameById.get(pharmacyId),
          auditDate: isoDate(auditDate),
          ownBrandCounts: products.map((p) => ({productId: p.id, productName: p.name, count: 8 + (i % 10)})),
          competitorCounts: [{brandName: `Test Competitor Brand ${(i % 3) + 1}`, count: 3 + (i % 6)}],
          notes: `Test RCPA entry #${i + 1}`,
          latitude: null,
          longitude: null,
          createdAt: auditDate,
          testSeed: true,
        });
        manifest.rcpaEntryIds.push(ref.id);
        flushManifest();
      }
      console.log(`  ${RCPA_COUNT} RCPA entries created.`);
    }

    // ---- 11. Compliance logs: >=10, every category represented ----
    console.log("Creating compliance logs...");
    const COMPLIANCE_CATEGORIES = ["sample", "gift", "sponsorship", "hospitality", "other"];
    const COMPLIANCE_COUNT = 15;
    for (let i = 0; i < COMPLIANCE_COUNT; i++) {
      const mr = mrEntries[i % mrEntries.length];
      const doctorIds = doctorIdsByMr.get(mr.key)!;
      const doctorId = doctorIds[i % doctorIds.length];
      const category = COMPLIANCE_CATEGORIES[i % COMPLIANCE_CATEGORIES.length];
      const logDate = spreadOverSixMonths(i, COMPLIANCE_COUNT);
      const ref = await firestore.collection("ComplianceLogs").add({
        mrUid: mr.uid,
        mrName: mr.name,
        doctorId,
        doctorName: doctorNameById.get(doctorId),
        category,
        description: `Test ${category} entry #${i + 1}`,
        value: 100 + ((i * 37) % 500),
        logDate: isoDate(logDate),
        createdAt: logDate,
        testSeed: true,
      });
      manifest.complianceLogIds.push(ref.id);
      flushManifest();
    }
    console.log(`  ${COMPLIANCE_COUNT} compliance logs created, covering every category.`);

    // ---- 12. Visit plans (one per MR, every status represented) + visit logs ----
    console.log("Creating visit plans (one per MR)...");
    const VISIT_PLAN_STATUSES = ["draft", "pending", "approved", "rejected"];
    for (let i = 0; i < mrEntries.length; i++) {
      const mr = mrEntries[i];
      const status = VISIT_PLAN_STATUSES[i % VISIT_PLAN_STATUSES.length];
      const doctorIds = doctorIdsByMr.get(mr.key)!;
      const abmUid = chainByKey.get(mr.key)![0];
      const decidedAt = status === "approved" || status === "rejected" ? spreadOverSixMonths(i, mrEntries.length) : null;
      await firestore.collection("DoctorVisitPlans").doc(mr.uid).set({
        monday: [doctorIds[0]],
        tuesday: [doctorIds[1]],
        wednesday: [doctorIds[2]],
        thursday: [],
        friday: [],
        saturday: [],
        sunday: [],
        status,
        approvedByUid: status === "approved" ? abmUid : null,
        approvedAt: status === "approved" ? decidedAt : null,
        rejectedReason: status === "rejected" ? "Test rejection - please revise coverage" : null,
        testSeed: true,
      });
      manifest.visitPlanMrUids.push(mr.uid);
      flushManifest();
    }
    console.log(`  ${mrEntries.length} visit plans created, covering every status.`);

    console.log("Creating visit logs...");
    const VISIT_LOG_COUNT = 20;
    for (let i = 0; i < VISIT_LOG_COUNT; i++) {
      const mr = mrEntries[i % mrEntries.length];
      const doctorIds = doctorIdsByMr.get(mr.key)!;
      const doctorId = doctorIds[i % doctorIds.length];
      const visited = i % 3 !== 0; // both true and false represented
      const visitDate = spreadOverSixMonths(i, VISIT_LOG_COUNT);
      const ref = await firestore.collection("DoctorVisitLogs").add({
        mrUid: mr.uid,
        doctorId,
        doctorName: doctorNameById.get(doctorId),
        visitDate: isoDate(visitDate),
        visited,
        feedback: visited ? "Test feedback - doctor was receptive" : "Test feedback - doctor unavailable, rescheduled",
        latitude: null,
        longitude: null,
        samplesGiven: visited ? {[`test-product-${(i % 3) + 1}`]: 2 + (i % 4)} : {},
        createdAt: visitDate,
        testSeed: true,
      });
      manifest.visitLogIds.push(ref.id);
      flushManifest();
    }
    console.log(`  ${VISIT_LOG_COUNT} visit logs created, covering both visited states.`);

    // ---- 13. Change requests: >=10 each, every type/status combo represented ----
    console.log("Creating doctor change requests...");
    const CR_TYPES = ["create", "update"];
    const CR_STATUSES = ["pending", "approved", "rejected"];
    const DOCTOR_CR_COUNT = 12;
    for (let i = 0; i < DOCTOR_CR_COUNT; i++) {
      const mr = mrEntries[i % mrEntries.length];
      const type = CR_TYPES[i % CR_TYPES.length];
      const status = CR_STATUSES[i % CR_STATUSES.length];
      const existingDoctorId = type === "update" ? doctorIdsByMr.get(mr.key)![0] : null;
      const ref = await firestore.collection("DoctorChangeRequests").add({
        type,
        doctorId: existingDoctorId,
        proposedData: type === "create" ?
          {
            name: `Dr. Test Proposed ${i + 1}`,
            specialisation: SPECIALISATIONS[i % SPECIALISATIONS.length],
            hospitalName: `Test Proposed Clinic ${i + 1}`,
            locationAddress: `${i + 1} Test Blvd, ${mr.areaName}`,
            doctorPhotoUrls: [],
            hospitalPhotoUrls: [],
          } :
          {hospitalName: `Test Updated Hospital ${i + 1}`},
        requestedByUid: mr.uid,
        requestedByName: mr.name,
        status,
        createdAt: spreadOverSixMonths(i, DOCTOR_CR_COUNT),
        testSeed: true,
      });
      manifest.doctorChangeRequestIds.push(ref.id);
      flushManifest();
    }
    console.log(`  ${DOCTOR_CR_COUNT} doctor change requests created, covering every type/status combo.`);

    console.log("Creating entity change requests...");
    const ENTITY_TYPES = ["agency", "pharmacy"];
    const ENTITY_CR_COUNT = 12;
    for (let i = 0; i < ENTITY_CR_COUNT; i++) {
      const mr = mrEntries[i % mrEntries.length];
      const entityType = ENTITY_TYPES[i % ENTITY_TYPES.length];
      const type = CR_TYPES[i % CR_TYPES.length];
      const status = CR_STATUSES[i % CR_STATUSES.length];
      const existingEntityId = type === "update" ?
        (entityType === "agency" ? agencyIdByAreaIndex.get(mr.areaIndex)! : pharmacyIdsByMr.get(mr.key)![0]) :
        null;
      const proposedData = entityType === "agency" ?
        {name: `TEST Proposed Agency ${i + 1}`, address: `${i + 1} Test Lane, ${mr.areaName}`, active: true} :
        {name: `TEST Proposed Pharmacy ${i + 1}`, address: `${i + 1} Test Lane, ${mr.areaName}`, active: true};
      const ref = await firestore.collection("EntityChangeRequests").add({
        entityType,
        type,
        entityId: existingEntityId,
        proposedData,
        requestedByUid: mr.uid,
        requestedByName: mr.name,
        status,
        createdAt: spreadOverSixMonths(i, ENTITY_CR_COUNT),
        testSeed: true,
      });
      manifest.entityChangeRequestIds.push(ref.id);
      flushManifest();
    }
    console.log(`  ${ENTITY_CR_COUNT} entity change requests created, covering every type/status combo.`);

    // ---- 14. Usage sessions: >=10, spread across MRs and 6 months ----
    console.log("Creating usage sessions...");
    const USAGE_SESSION_COUNT = 24;
    for (let i = 0; i < USAGE_SESSION_COUNT; i++) {
      const mr = mrEntries[i % mrEntries.length];
      const openedAt = spreadOverSixMonths(i, USAGE_SESSION_COUNT);
      const durationSeconds = 1200 + ((i * 173) % 5400);
      const closedAt = new Date(openedAt.getTime() + durationSeconds * 1000);
      const ref = await firestore.collection("UsageSessions").add({
        employeeUid: mr.uid,
        username: mr.username,
        openedAt,
        closedAt,
        durationSeconds,
        latitude: null,
        longitude: null,
        uploadedAt: closedAt,
        testSeed: true,
      });
      manifest.usageSessionIds.push(ref.id);
      flushManifest();
    }
    console.log(`  ${USAGE_SESSION_COUNT} usage sessions created.`);

    // ---- 15. Reminders: >=10, both completed states represented ----
    console.log("Creating reminders...");
    const REMINDER_COUNT = 12;
    for (let i = 0; i < REMINDER_COUNT; i++) {
      const mr = mrEntries[i % mrEntries.length];
      const creator = officeAdminEntries[i % officeAdminEntries.length];
      const completed = i % 2 === 0;
      const dueAt = new Date(Date.now() + ((i % 6) - 3) * 24 * 60 * 60 * 1000);
      const ref = await firestore.collection("Reminders").add({
        ownerUid: mr.uid,
        ownerName: mr.name,
        createdByUid: creator.uid,
        createdByName: creator.name,
        title: `TEST: Follow up #${i + 1}`,
        note: "Seeded test reminder",
        dueAt,
        completed,
        notified: completed,
        createdAt: spreadOverSixMonths(i, REMINDER_COUNT),
        testSeed: true,
      });
      manifest.reminderIds.push(ref.id);
      flushManifest();
    }
    console.log(`  ${REMINDER_COUNT} reminders created, covering both completed states.`);

    // ---- 16. Write every login to a single Excel workbook ----
    console.log("Writing credentials workbook...");
    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet("Test Logins");
    sheet.columns = [
      {header: "Name", key: "name", width: 34},
      {header: "Role", key: "abbr", width: 8},
      {header: "Designation", key: "designation", width: 34},
      {header: "Reports To", key: "managerName", width: 26},
      {header: "Area", key: "areaName", width: 16},
      {header: "Username", key: "username", width: 22},
      {header: "Email", key: "email", width: 42},
      {header: "Password", key: "password", width: 16},
    ];
    sheet.getRow(1).font = {bold: true};
    for (const login of manifest.logins) {
      sheet.addRow({
        name: `${login.fullName} (${login.abbr})`,
        abbr: login.abbr,
        designation: login.role,
        managerName: login.managerName,
        areaName: login.areaName,
        username: login.username,
        email: login.email,
        password: login.password,
      });
    }
    sheet.autoFilter = {from: "A1", to: "H1"};
    await workbook.xlsx.writeFile(CREDENTIALS_XLSX_PATH);
    console.log(`  Credentials workbook written to ${CREDENTIALS_XLSX_PATH}`);

    console.log(`\nDone. ${manifest.logins.length} test accounts created — full roster in the workbook above.`);
    console.log(
      "\nNote: log in with the FULL EMAIL (with @), not the bare username — a bare username resolves to a" +
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
