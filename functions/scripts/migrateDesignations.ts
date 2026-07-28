/**
 * One-off migration: backfills category/hierarchyLevel/parentDesignationId/
 * permissions onto the 5 pre-existing designation docs and seeds the 4 new
 * ones (CEO, COO, Admin Manager, HR) needed for the role-based hierarchy.
 * Not shipped app UI — run once via `npm run migrate:designations` (see
 * functions/package.json), using the same Firebase Auth as `firebase
 * deploy` (Application Default Credentials), against whichever project the
 * Firebase CLI is currently pointed at.
 *
 * Idempotent by name: re-running it updates existing docs in place (matched
 * case-insensitively by `name`) rather than creating duplicates.
 */
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

interface SeedDesignation {
  name: string;
  category: "field" | "office_administration" | "executive";
  hierarchyLevel: number;
  parentName: string | null; // resolved to parentDesignationId after all docs exist
  permissions: string[];
}

const SEED: SeedDesignation[] = [
  {
    name: "CEO",
    category: "executive",
    hierarchyLevel: 0,
    parentName: null,
    permissions: ["approve_orders", "dispatch_orders", "manage_invoices", "approve_requests", "view_global_data"],
  },
  {
    name: "COO",
    category: "executive",
    hierarchyLevel: 0,
    parentName: null,
    permissions: ["approve_orders", "dispatch_orders", "manage_invoices", "approve_requests", "view_global_data"],
  },
  {
    name: "Admin Manager",
    category: "office_administration",
    hierarchyLevel: 1,
    parentName: null,
    permissions: ["approve_orders", "dispatch_orders", "manage_invoices", "approve_requests", "view_global_data"],
  },
  {
    name: "HR",
    category: "office_administration",
    hierarchyLevel: 1,
    parentName: null,
    permissions: [],
  },
  {
    name: "Zonal Business Manager",
    category: "field",
    hierarchyLevel: 1,
    parentName: null,
    permissions: ["approve_orders", "approve_requests"],
  },
  {
    name: "Regional Business Manager",
    category: "field",
    hierarchyLevel: 2,
    parentName: "Zonal Business Manager",
    permissions: ["approve_orders", "approve_requests"],
  },
  {
    name: "Area Business Manager",
    category: "field",
    hierarchyLevel: 3,
    parentName: "Regional Business Manager",
    permissions: ["approve_orders", "approve_requests"],
  },
  {
    name: "Senior Medical Representative",
    category: "field",
    hierarchyLevel: 5,
    parentName: "Area Business Manager",
    permissions: ["create_orders"],
  },
  {
    name: "Medical Representative",
    category: "field",
    hierarchyLevel: 5,
    parentName: "Area Business Manager",
    permissions: ["create_orders"],
  },
];

async function main(): Promise<void> {
  initializeApp();
  const firestore = getFirestore();
  const collection = firestore.collection("Designations");

  const existing = await collection.get();
  const idByName = new Map<string, string>();
  for (const doc of existing.docs) {
    const name = doc.data().name as string | undefined;
    if (name) idByName.set(name.toLowerCase(), doc.id);
  }

  // Pass 1: upsert every doc (without parentDesignationId yet — the parent
  // might not have an id assigned until this same pass creates it).
  for (const seed of SEED) {
    const existingId = idByName.get(seed.name.toLowerCase());
    const data = {
      name: seed.name,
      category: seed.category,
      hierarchyLevel: seed.hierarchyLevel,
      permissions: seed.permissions,
    };
    if (existingId) {
      await collection.doc(existingId).set(data, {merge: true});
      console.log(`Updated "${seed.name}" (${existingId})`);
    } else {
      const ref = await collection.add(data);
      idByName.set(seed.name.toLowerCase(), ref.id);
      console.log(`Created "${seed.name}" (${ref.id})`);
    }
  }

  // Pass 2: now every seeded designation has an id, resolve parentName -> parentDesignationId.
  for (const seed of SEED) {
    const id = idByName.get(seed.name.toLowerCase());
    if (!id) continue;
    const parentDesignationId = seed.parentName ? idByName.get(seed.parentName.toLowerCase()) ?? null : null;
    await collection.doc(id).set({parentDesignationId}, {merge: true});
  }

  console.log("Done.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("migrateDesignations failed:", error);
    process.exit(1);
  });
