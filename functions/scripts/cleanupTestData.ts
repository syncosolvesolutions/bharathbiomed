/**
 * Removes exactly what seedTestData.ts created, by reading the manifest it
 * wrote to MANIFEST_PATH — never queries/guesses at what "looks like" test
 * data, so it can't touch real records (or Products/Department, which it
 * never even references). Every delete is individually try/caught and
 * idempotent-safe (a Firestore delete on an already-gone doc, or
 * auth.deleteUser on an already-gone user, is treated as success), so
 * running this twice — or after a partial failure — is safe. Run via
 * `npm run test:cleanup`.
 */
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
import * as fs from "fs";
import * as path from "path";

const MANIFEST_PATH = path.join(__dirname, "..", ".test-seed-manifest.json");

interface Manifest {
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
}

async function main(): Promise<void> {
  if (!fs.existsSync(MANIFEST_PATH)) {
    console.log(`No manifest found at ${MANIFEST_PATH} — nothing to clean up.`);
    return;
  }

  const manifest: Manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf8"));

  initializeApp();
  const firestore = getFirestore();
  const auth = getAuth();

  let errorCount = 0;
  const errors: string[] = [];

  async function deleteDoc(collection: string, id: string): Promise<void> {
    try {
      await firestore.collection(collection).doc(id).delete();
    } catch (error) {
      errorCount++;
      errors.push(`${collection}/${id}: ${String(error)}`);
    }
  }

  async function deleteDocs(collection: string, ids: string[]): Promise<void> {
    for (const id of ids) await deleteDoc(collection, id);
    if (ids.length > 0) console.log(`  Deleted ${ids.length} ${collection} doc(s).`);
  }

  console.log("Deleting test employees (Auth + Users docs)...");
  for (const uid of manifest.employeeUids) {
    try {
      await auth.deleteUser(uid);
    } catch (error) {
      const code = (error as {code?: string}).code;
      if (code !== "auth/user-not-found") {
        errorCount++;
        errors.push(`Auth user ${uid}: ${String(error)}`);
      }
    }
    await deleteDoc("Users", uid);
  }
  console.log(`  Deleted ${manifest.employeeUids.length} employee(s).`);

  console.log("Deleting other test data...");
  await deleteDocs("DoctorVisitPlans", manifest.visitPlanMrUids);
  await deleteDocs("DoctorVisitLogs", manifest.visitLogIds);
  await deleteDocs("RcpaEntries", manifest.rcpaEntryIds);
  await deleteDocs("ComplianceLogs", manifest.complianceLogIds);
  await deleteDocs("ExpenseClaims", manifest.expenseClaimIds);
  await deleteDocs("SalesTargets", manifest.salesTargetIds);
  await deleteDocs("Orders", manifest.orderIds);
  await deleteDocs("DoctorChangeRequests", manifest.doctorChangeRequestIds);
  await deleteDocs("EntityChangeRequests", manifest.entityChangeRequestIds);
  await deleteDocs("UsageSessions", manifest.usageSessionIds);
  await deleteDocs("Reminders", manifest.reminderIds);
  await deleteDocs("Pharmacies", manifest.pharmacyIds);
  await deleteDocs("Agencies", manifest.agencyIds);
  await deleteDocs("Doctors", manifest.doctorIds);
  await deleteDocs("Designations", manifest.designationIds);

  if (errorCount > 0) {
    console.error(`\n${errorCount} deletion(s) failed:`);
    for (const e of errors) console.error(`  - ${e}`);
    console.error("\nManifest kept so you can re-run `npm run test:cleanup` to retry the failures.");
    process.exit(1);
  }

  fs.unlinkSync(MANIFEST_PATH);
  console.log("\nAll test data removed. Manifest deleted — back to the pre-seed state.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("cleanupTestData failed:", error);
    process.exit(1);
  });
