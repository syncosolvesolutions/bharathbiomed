import {HttpsError} from "firebase-functions/v2/https";
import type {CallableRequest} from "firebase-functions/v2/https";
import {getFirestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

// Mirrors the allowlist in lib/core/auth/admin_access.dart on the Flutter
// side. That client-side check only controls what the UI shows; this is the
// check that actually matters, since it runs on the server and can't be
// bypassed by a modified client.
const ADMIN_EMAILS = new Set([
  "bharathbiomedpharma@gmail.com",
  "sudhakar.gotte@bharathbiomedpharma.com",
]);

/**
 * Synthetic email domain for Medical Representative accounts. MRs log in
 * with a short username (e.g. "rajesh"), not a real email address, so their
 * Firebase Auth account uses `mr-<username>@<this domain>` under the hood.
 * Using this project's own Firebase Hosting domain guarantees the address
 * can never collide with, or accidentally notify, a real third party.
 */
export const EMPLOYEE_EMAIL_DOMAIN = "bharathbiomedpharma-6c6c3.firebaseapp.com";

export function usernameToEmail(username: string): string {
  logger.info("usernameToEmail: called", {username});
  return `mr-${username}@${EMPLOYEE_EMAIL_DOMAIN}`;
}

export function requireAdmin(request: CallableRequest): string {
  logger.info("requireAdmin: called");
  const email = request.auth?.token?.email;
  if (!request.auth || !email || !ADMIN_EMAILS.has(email)) {
    // request.auth is only ever missing here if the call somehow reached our
    // handler without a valid Firebase Auth ID token attached (App Check
    // enforcement rejecting the request, or an IAM/invoker misconfiguration,
    // would normally be rejected before this code even runs — see the
    // UNAUTHENTICATED note in the client-side error mapping). Logging both
    // cases (no auth at all vs. wrong email) so a rejection here is always
    // traceable in Cloud Functions logs instead of a silent denial.
    logger.warn("requireAdmin: rejected", {hasAuth: !!request.auth, email: email ?? null});
    throw new HttpsError("permission-denied", "Only an admin can perform this action.");
  }
  return request.auth.uid;
}

/**
 * Non-admin (designation/permission-based) role gate for Order/Invoice-style
 * callables — separate from and unrelated to [requireAdmin]'s hardcoded
 * allowlist (see `Users/{uid}.permissions`, denormalized from the caller's
 * assigned designation by `functions/src/hierarchy.ts`). Checks live
 * Firestore state rather than a custom claim/token field, since permissions
 * can change at any time via the admin's designation editor and a signed-in
 * user's ID token isn't refreshed on that timescale.
 */
export async function requirePermission(request: CallableRequest, permission: string): Promise<string> {
  logger.info("requirePermission: called", {permission});
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  const uid = request.auth.uid;
  const userDoc = await getFirestore().collection("Users").doc(uid).get();
  const permissions = (userDoc.data()?.permissions as string[] | undefined) ?? [];
  if (!userDoc.exists || userDoc.data()?.role !== "mr" || !permissions.includes(permission)) {
    logger.warn("requirePermission: rejected", {uid, permission, exists: userDoc.exists});
    throw new HttpsError("permission-denied", `This action requires the "${permission}" permission.`);
  }
  return uid;
}
