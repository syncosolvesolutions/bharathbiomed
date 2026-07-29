/**
 * One-time copy of the real `Products` collection (+ each product's
 * `Batches` subcollection) and the `Department/departmentsDoc` document from
 * one Firebase project into another — used when standing up a new project
 * (e.g. bharathbiomed-14368) that needs the same catalog as the existing one,
 * unlike seedTestData.ts, which deliberately never touches this data.
 *
 * Read-only against --source. Preserves document ids on --target (uses
 * `.doc(id).set(...)` instead of `.add(...)`) so nothing else that might
 * reference a product id stays in sync.
 *
 * Uses the same Application Default Credentials as `firebase deploy` (see
 * migrateDesignations.ts) — the authenticated account needs Firestore
 * read/write access on both projects. Run via:
 *   npm run clone:catalog -- --source=<projectId> --target=<projectId>
 */
import {initializeApp, applicationDefault} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

function requiredArg(name: string): string {
  const prefix = `--${name}=`;
  const arg = process.argv.find((a) => a.startsWith(prefix));
  if (!arg) {
    console.error(`Missing required --${name}=<projectId> argument.`);
    process.exit(64);
  }
  return arg.slice(prefix.length);
}

async function main(): Promise<void> {
  const sourceProjectId = requiredArg("source");
  const targetProjectId = requiredArg("target");
  if (sourceProjectId === targetProjectId) {
    console.error("--source and --target must be different projects.");
    process.exit(64);
  }

  const sourceApp = initializeApp({credential: applicationDefault(), projectId: sourceProjectId}, "source");
  const targetApp = initializeApp({credential: applicationDefault(), projectId: targetProjectId}, "target");
  const sourceDb = getFirestore(sourceApp);
  const targetDb = getFirestore(targetApp);

  console.log(`Copying Products: ${sourceProjectId} -> ${targetProjectId}`);
  const productsSnapshot = await sourceDb.collection("Products").get();
  let batchCount = 0;
  for (const productDoc of productsSnapshot.docs) {
    await targetDb.collection("Products").doc(productDoc.id).set(productDoc.data());
    console.log(`  Product "${productDoc.data().name ?? productDoc.id}" (${productDoc.id})`);

    const batchesSnapshot = await productDoc.ref.collection("Batches").get();
    for (const batchDoc of batchesSnapshot.docs) {
      await targetDb
        .collection("Products")
        .doc(productDoc.id)
        .collection("Batches")
        .doc(batchDoc.id)
        .set(batchDoc.data());
      batchCount++;
    }
  }
  console.log(`Copied ${productsSnapshot.docs.length} products, ${batchCount} batches.`);

  console.log("Copying Department/departmentsDoc");
  const departmentsDoc = await sourceDb.collection("Department").doc("departmentsDoc").get();
  if (departmentsDoc.exists) {
    await targetDb.collection("Department").doc("departmentsDoc").set(departmentsDoc.data() ?? {});
    console.log("  Copied departmentsDoc.");
  } else {
    console.log("  No departmentsDoc found on source — nothing to copy.");
  }

  console.log("Done.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("cloneProductsCatalog failed:", error);
    process.exit(1);
  });
