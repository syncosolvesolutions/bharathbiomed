import {getFirestore} from "firebase-admin/firestore";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";

// Cycle/misconfiguration guard — no real org is this deep, so hitting this
// means `managerId` forms a loop or the chain is otherwise broken.
const MAX_CHAIN_DEPTH = 20;
const BATCH_SIZE = 500; // Firestore's per-batch write limit.

function chunk<T>(items: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    chunks.push(items.slice(i, i + size));
  }
  return chunks;
}

/** Walks `managerId` up from `uid`, returning the ordered chain (direct manager first). */
async function computeChain(uid: string): Promise<string[]> {
  const firestore = getFirestore();
  const chain: string[] = [];
  let currentUid: string | undefined = uid;
  for (let i = 0; i < MAX_CHAIN_DEPTH; i++) {
    const doc = await firestore.collection("Users").doc(currentUid).get();
    const managerId = doc.data()?.managerId as string | undefined;
    if (!managerId || chain.includes(managerId)) break; // no manager, or a cycle
    chain.push(managerId);
    currentUid = managerId;
  }
  return chain;
}

/**
 * Recomputes `uid`'s own denormalized org fields (reportingChainUids +
 * category/hierarchyLevel/permissions copied from its designation), then
 * cascades reportingChainUids to every existing descendant. Cascading is a
 * single flat query rather than a multi-level walk: since each user's chain
 * already stores their *full* ancestor list (not just their direct manager),
 * "who is in uid's subtree" is exactly "who currently lists uid anywhere in
 * their chain" — grandchildren included.
 */
export async function recomputeAndCascade(uid: string): Promise<void> {
  logger.info("recomputeAndCascade: called", {uid});
  const firestore = getFirestore();
  const userRef = firestore.collection("Users").doc(uid);
  const userDoc = await userRef.get();
  if (!userDoc.exists) {
    logger.info("recomputeAndCascade: user doc no longer exists, skipping", {uid});
    return;
  }

  const designationId = userDoc.data()?.designationId as string | undefined;
  let category: string | null = null;
  let hierarchyLevel: number | null = null;
  let permissions: string[] = [];
  if (designationId) {
    const designationDoc = await firestore.collection("Designations").doc(designationId).get();
    if (designationDoc.exists) {
      category = (designationDoc.data()?.category as string) ?? "field";
      hierarchyLevel = (designationDoc.data()?.hierarchyLevel as number) ?? 0;
      permissions = (designationDoc.data()?.permissions as string[]) ?? [];
    }
  }

  const reportingChainUids = await computeChain(uid);
  await userRef.update({reportingChainUids, category, hierarchyLevel, permissions});
  logger.info("recomputeAndCascade: updated own fields", {uid, chainLength: reportingChainUids.length});

  const descendants = await firestore.collection("Users").where("reportingChainUids", "array-contains", uid).get();
  logger.info("recomputeAndCascade: cascading to descendants", {uid, descendantCount: descendants.docs.length});
  for (const batchDocs of chunk(descendants.docs, BATCH_SIZE)) {
    const writeBatch = firestore.batch();
    for (const doc of batchDocs) {
      const newChain = await computeChain(doc.id);
      writeBatch.update(doc.ref, {reportingChainUids: newChain});
    }
    await writeBatch.commit();
  }
  logger.info("recomputeAndCascade: done", {uid});
}

/**
 * Recomputes an employee's org fields whenever their `managerId` or
 * `designationId` changes. The guard below is also what stops
 * [recomputeAndCascade]'s own writes from re-triggering this function
 * infinitely — those writes only ever touch reportingChainUids/category/
 * hierarchyLevel/permissions, never managerId/designationId, so they fail
 * the guard and return immediately.
 */
export const onUserOrgChanged = onDocumentWritten("Users/{uid}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!after) return; // deleted
  if (before?.managerId === after.managerId && before?.designationId === after.designationId) return;
  logger.info("onUserOrgChanged: org fields changed, recomputing", {uid: event.params.uid});
  await recomputeAndCascade(event.params.uid);
});

/**
 * When a designation's own hierarchyLevel/permissions/category change,
 * recomputes every employee currently assigned to it (their denormalized
 * copies would otherwise go stale).
 */
export const onDesignationOrgChanged = onDocumentWritten("Designations/{designationId}", async (event) => {
  const after = event.data?.after?.data();
  if (!after) return; // deleted — existing employees keep their last-known denormalized values
  const designationId = event.params.designationId as string;
  logger.info("onDesignationOrgChanged: designation changed, recomputing assigned employees", {designationId});
  const affected = await getFirestore().collection("Users").where("designationId", "==", designationId).get();
  for (const doc of affected.docs) {
    await recomputeAndCascade(doc.id);
  }
});
