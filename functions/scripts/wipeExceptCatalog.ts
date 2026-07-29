/**
 * Wipes every Firestore collection except `Products` and `Department` (and
 * `Products/{id}/Batches`, preserved automatically since `Products` itself
 * is never touched), plus every Firebase Auth user except the hardcoded
 * admin allowlist below — for resetting the whole test environment back to
 * just the product/department catalog between test cycles, without having
 * to re-upload the catalog every time.
 *
 * Pass `--include-catalog` to also wipe `Products` and `Department` (e.g.
 * right before re-cloning the catalog from another project with
 * `cloneProductsCatalog.ts` — see its doc comment / `npm run clone:catalog`).
 * Off by default so the common "reset test data, keep my catalog" case
 * can't accidentally take the catalog with it.
 *
 * Unlike seedTestData.ts/cleanupTestData.ts, this has no manifest to scope
 * itself to — it deletes real data indiscriminately, admin-created or
 * test-seeded alike, everywhere except (unless --include-catalog) the two
 * collections above. It is NOT part of the seed/cleanup pair and does not
 * read or write .test-seed-manifest.json. Requires typing an exact
 * confirmation phrase at an interactive prompt before it deletes anything.
 *
 * ADMIN_EMAILS below must be kept in sync with the allowlist in
 * functions/src/adminAccess.ts (both ultimately generated from
 * tenants/<tenantId>/tenant.json by scripts/apply_tenant.dart) — this is
 * what stops the script from deleting the real admin's own sign-in and
 * locking them out of the app. Run via `npm run wipe:all` (or
 * `npm run wipe:all -- --include-catalog`).
 */
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
import * as readline from "readline";

const ADMIN_EMAILS = new Set([
  // Keep in sync with functions/src/adminAccess.ts's ADMIN_EMAILS.
  "bharathbiomedpharma@gmail.com",
  "sudhakar.gotte@bharathbiomedpharma.com",
]);

const CONFIRMATION_PHRASE = "DELETE EVERYTHING";
const INCLUDE_CATALOG = process.argv.includes("--include-catalog");
const CATALOG_COLLECTIONS = ["Products", "Department"];

// Every collection here gets fully wiped, including any subcollections
// (via Firestore's recursiveDelete) — every top-level collection in
// firestore.rules EXCEPT Products and Department (added back in via
// --include-catalog).
const COLLECTIONS_TO_WIPE = [
  "Designations",
  "Users",
  "AdminProfile",
  "AdminNotifications",
  "UsageSessions",
  "Doctors",
  "DoctorChangeRequests",
  "DoctorVisitPlans",
  "DoctorVisitLogs",
  "RcpaEntries",
  "ComplianceLogs",
  "Reminders",
  "Agencies",
  "Pharmacies",
  "EntityChangeRequests",
  "Orders",
  "SalesTargets",
  "ExpenseClaims",
  "DeviceTokens",
];

function prompt(question: string): Promise<string> {
  const rl = readline.createInterface({input: process.stdin, output: process.stdout});
  return new Promise((resolve) => rl.question(question, (answer) => {
    rl.close();
    resolve(answer);
  }));
}

async function main(): Promise<void> {
  const app = initializeApp();
  const firestore = getFirestore();
  const auth = getAuth();
  const projectId = app.options.projectId ?? "(unknown — check `firebase use`)";
  const collectionsToWipe = INCLUDE_CATALOG ? [...COLLECTIONS_TO_WIPE, ...CATALOG_COLLECTIONS] : COLLECTIONS_TO_WIPE;

  console.log(`Target project: ${projectId}\n`);
  console.log("This will PERMANENTLY delete every document in:");
  for (const name of collectionsToWipe) console.log(`  - ${name}`);
  console.log("\n...and every Firebase Auth user EXCEPT:");
  for (const email of ADMIN_EMAILS) console.log(`  - ${email} (kept)`);
  if (INCLUDE_CATALOG) {
    console.log(
      "\n--include-catalog was passed: Products and Department (and Products' Batches\n" +
        "subcollection) WILL ALSO be deleted — nothing survives except the admin login(s) above.\n" +
        "This does NOT use the seed/cleanup manifest — it deletes real data indiscriminately.\n"
    );
  } else {
    console.log(
      "\nOnly `Products`, `Department`, and Products' `Batches` subcollection are preserved\n" +
        "(pass --include-catalog to wipe those too).\n" +
        "This does NOT use the seed/cleanup manifest — it deletes real data indiscriminately,\n" +
        "admin-created or test-seeded alike, in every collection above.\n"
    );
  }

  const answer = await prompt(`Type "${CONFIRMATION_PHRASE}" (exact case) to proceed, or Ctrl+C to abort: `);
  if (answer !== CONFIRMATION_PHRASE) {
    console.error("Confirmation did not match. Aborting — nothing was deleted.");
    process.exit(1);
  }

  console.log("\nDeleting Firestore collections...");
  for (const name of collectionsToWipe) {
    await firestore.recursiveDelete(firestore.collection(name));
    console.log(`  Wiped ${name}.`);
  }

  console.log("\nDeleting Auth users (except the admin allowlist)...");
  let deletedCount = 0;
  let pageToken: string | undefined;
  do {
    const page = await auth.listUsers(1000, pageToken);
    const uidsToDelete = page.users.filter((u) => !u.email || !ADMIN_EMAILS.has(u.email)).map((u) => u.uid);
    if (uidsToDelete.length > 0) {
      const result = await auth.deleteUsers(uidsToDelete);
      deletedCount += result.successCount;
      if (result.failureCount > 0) {
        console.error(`  ${result.failureCount} Auth deletion(s) failed:`);
        for (const err of result.errors) console.error(`    - ${err.error.message}`);
      }
    }
    pageToken = page.pageToken;
  } while (pageToken);
  console.log(`  Deleted ${deletedCount} Auth user(s). Kept ${ADMIN_EMAILS.size} admin account(s).`);

  console.log(
    INCLUDE_CATALOG ?
      "\nDone. Everything was wiped, including Products/Department — only the admin login(s) above remain." :
      "\nDone. Only Products/Department (and Products' Batches) remain, plus the admin login(s) above."
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("wipeExceptCatalog failed:", error);
    process.exit(1);
  });
