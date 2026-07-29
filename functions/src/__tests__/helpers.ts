import type {CallableRequest} from "firebase-functions/v2/https";
import functionsTest from "firebase-functions-test";

// `firebase emulators:exec` (see scripts/test-with-emulator.sh) already sets
// FIRESTORE_EMULATOR_HOST/GCLOUD_PROJECT for this process — these are just a
// safety net for running a test file directly against an already-running
// emulator without going through that wrapper.
process.env.GCLOUD_PROJECT ||= "demo-bharathbiomedpharma";
process.env.FIRESTORE_EMULATOR_HOST ||= "localhost:8080";

// Offline mode: only used for `wrap()` below, not for its own Firebase app —
// ../index already calls `initializeApp()` at import time, and every
// `getFirestore()` call in that module picks up FIRESTORE_EMULATOR_HOST
// above, so tests talk to the same emulator instance instead of production.
export const testEnv = functionsTest();

/** Builds a minimal `CallableRequest` — enough for `requirePermission`/
 * `requireAdmin`/`requireOfficeAdminOrPermission` (which only read
 * `auth.uid` and `auth.token.email`) and each callable's own
 * `request.data`. */
export function callableRequest<T>(data: T, options?: {uid?: string; email?: string}): CallableRequest<T> {
  return {
    data,
    auth: options?.uid
      ? ({uid: options.uid, token: {email: options.email} as unknown} as CallableRequest["auth"])
      : undefined,
    rawRequest: {} as CallableRequest["rawRequest"],
  } as CallableRequest<T>;
}

export async function seedUser(
  firestore: FirebaseFirestore.Firestore,
  uid: string,
  data: {role?: string; permissions?: string[]; category?: string; reportingChainUids?: string[]}
): Promise<void> {
  await firestore.collection("Users").doc(uid).set(data, {merge: true});
}

export async function clearFirestore(firestore: FirebaseFirestore.Firestore): Promise<void> {
  const collections = await firestore.listCollections();
  await Promise.all(collections.map((collection) => firestore.recursiveDelete(collection)));
}
