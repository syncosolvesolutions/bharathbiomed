import {HttpsError} from "firebase-functions/v2/https";
import type {CallableRequest} from "firebase-functions/v2/https";
import {getFirestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

// Mirrors the allowlist in lib/core/auth/admin_access.dart on the Flutter
// side. That client-side check only controls what the UI shows; this is the
// check that actually matters, since it runs on the server and can't be
// bypassed by a modified client. Both this array and firestore.rules'
// isAdmin() are generated from the same tenants/<tenantId>/tenant.json by
// scripts/apply_tenant.dart — edit the json and re-run that script, don't
// hand-edit either copy. Do not remove the marker comments below; the
// script replaces everything between them.
const ADMIN_EMAILS = new Set([
  // TENANT-ADMIN-EMAILS:START
  "bharathbiomedpharma@gmail.com",
  "sudhakar.gotte@bharathbiomedpharma.com",
  // TENANT-ADMIN-EMAILS:END
]);

/**
 * Synthetic email domain for Medical Representative accounts. MRs log in
 * with a short username (e.g. "rajesh"), not a real email address, so their
 * Firebase Auth account uses `mr-<username>@<this domain>` under the hood.
 * Derived from this function's own deployed project id (never hardcoded),
 * so it can never drift from the Firebase project it's actually running in
 * — mirrors lib/core/auth/employee_login.dart's `employeeEmailDomain`,
 * which derives the same value client-side from `Firebase.app().options
 * .authDomain`. Both must keep resolving to the same domain.
 */
export const EMPLOYEE_EMAIL_DOMAIN = `${process.env.GCLOUD_PROJECT}.firebaseapp.com`;

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
 * Non-admin (designation/permission-based) role gate for Order-style
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

/**
 * Doctor-request review access: [requireAdmin]'s hardcoded allowlist, or any
 * real employee holding [permission] (in practice `approve_requests`) —
 * deliberately category-agnostic, so a senior field designation (e.g. Area
 * Business Manager and above) qualifies exactly the same way an Office
 * Administration designation would. See [requireOfficeAdminOrPermission] for
 * the equivalent on `EntityChangeRequests`, which additionally accepts
 * Office Admin category unconditionally.
 */
export async function requireAdminOrPermission(request: CallableRequest, permission: string): Promise<string> {
  logger.info("requireAdminOrPermission: called", {permission});
  const email = request.auth?.token?.email;
  if (request.auth && email && ADMIN_EMAILS.has(email)) {
    return request.auth.uid;
  }
  return requirePermission(request, permission);
}

/**
 * Agency/Pharmacy-request review access: unconditional for the hardcoded
 * admin allowlist or a real employee whose denormalized `category` is
 * `office_administration` (mirrors firestore.rules' `isOfficeAdmin()` —
 * gates agency/pharmacy create+deactivate too, but that path is a direct
 * rules-gated client write, not a callable, so there's no Cloud-Functions
 * helper for just that half anymore), plus any real employee holding
 * [permission] (in practice `approve_requests`) regardless of category — a
 * second, independent path onto the same action, added so a senior field
 * designation (e.g. Area Business Manager and above) can review these too.
 */
export async function requireOfficeAdminOrPermission(request: CallableRequest, permission: string): Promise<string> {
  logger.info("requireOfficeAdminOrPermission: called", {permission});
  const email = request.auth?.token?.email;
  if (request.auth && email && ADMIN_EMAILS.has(email)) {
    return request.auth.uid;
  }
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  const uid = request.auth.uid;
  const userDoc = await getFirestore().collection("Users").doc(uid).get();
  if (userDoc.data()?.category === "office_administration") {
    return uid;
  }
  const permissions = (userDoc.data()?.permissions as string[] | undefined) ?? [];
  if (!userDoc.exists || userDoc.data()?.role !== "mr" || !permissions.includes(permission)) {
    logger.warn("requireOfficeAdminOrPermission: rejected", {uid, permission});
    throw new HttpsError(
      "permission-denied",
      `This action requires Office Admin or the "${permission}" permission.`
    );
  }
  return uid;
}
