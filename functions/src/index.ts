import {DocumentSnapshot, FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getMessaging} from "firebase-admin/messaging";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

import {requireAdmin, requireOfficeAdmin, requirePermission, usernameToEmail} from "./adminAccess";

export {onUserOrgChanged, onDesignationOrgChanged} from "./hierarchy";

initializeApp();

const USERNAME_PATTERN = /^[a-z0-9._-]{3,32}$/;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
// Date-only, no time/timezone component — see Employee.dateOfBirth on the
// Flutter side for why this is stored as a plain string.
const DATE_OF_BIRTH_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

interface CreateEmployeeRequest {
  firstName: string;
  lastName: string;
  username: string;
  password: string;
  designation: string;
  areaName: string;
  mobileNumber?: string;
  photoUrl?: string;
  email: string;
  dateOfBirth?: string;
  designationId?: string;
  managerId?: string;
}

/**
 * Resolves and validates optional hierarchy fields for create/update: if
 * `designationId` is present it must point at a real `Designations` doc; if
 * `managerId` is also present, the candidate manager must be a real "mr"
 * account with a strictly lower `hierarchyLevel` than the designation being
 * assigned — the one hard universal rule (deliberately simple: category
 * pairing, e.g. "only a Field designation can report to another Field
 * designation", is left to client-side UI filtering, not enforced here).
 * Returns null values for either field left unset, matching how the rest of
 * this file treats "not provided" for optional employee fields.
 */
async function resolveHierarchyFields(
  designationId: string | undefined,
  managerId: string | undefined
): Promise<{designationId: string | null; managerId: string | null}> {
  logger.info("resolveHierarchyFields: called", {designationId: designationId ?? null, managerId: managerId ?? null});
  if (!designationId) {
    return {designationId: null, managerId: null};
  }

  const firestore = getFirestore();
  const designationDoc = await firestore.collection("Designations").doc(designationId).get();
  if (!designationDoc.exists) {
    throw new HttpsError("invalid-argument", "That designation no longer exists. Please pick another.");
  }
  const designationLevel = (designationDoc.data()?.hierarchyLevel as number) ?? 0;

  if (!managerId) {
    return {designationId, managerId: null};
  }

  const managerDoc = await firestore.collection("Users").doc(managerId).get();
  if (!managerDoc.exists || managerDoc.data()?.role !== "mr") {
    throw new HttpsError("invalid-argument", "That manager no longer exists. Please pick another.");
  }
  const managerLevel = managerDoc.data()?.hierarchyLevel as number | undefined;
  if (managerLevel === undefined || managerLevel >= designationLevel) {
    throw new HttpsError("invalid-argument", "The chosen manager must be higher in the hierarchy than this employee.");
  }

  return {designationId, managerId};
}

/**
 * Turns an Auth-SDK error into the right HttpsError. Always logs the
 * original error first — onCall sanitizes anything that isn't already an
 * HttpsError down to a bare "internal" error with no message before it
 * reaches the client, so without this log line the only trace of *why* an
 * Auth operation failed would be lost entirely.
 */
function rethrowAuthError(error: unknown, context: string): never {
  const code = (error as {code?: string}).code;
  logger.error(`${context}: Auth SDK error`, {code, error: String(error)});

  if (code === "auth/email-already-exists") {
    throw new HttpsError("already-exists", "That email or username is already taken.");
  }
  if (code === "auth/invalid-email") {
    throw new HttpsError("invalid-argument", "That email address looks invalid.");
  }
  if (code === "auth/invalid-password" || code === "auth/weak-password") {
    throw new HttpsError("invalid-argument", "Password must be at least 6 characters.");
  }
  if (code === "auth/too-many-requests" || code === "resource-exhausted") {
    throw new HttpsError("resource-exhausted", "Too many attempts. Please wait a moment and try again.");
  }
  // Any other Auth SDK error: still surface *something* useful to the admin
  // (an HttpsError's message reaches the client; a raw error's does not).
  throw new HttpsError("internal", `Failed to save this account (${code ?? "unknown error"}). Please try again.`);
}

/** Loads Users/{uid} and throws unless it's a profile this system created (role === "mr"). */
async function requireMrUserDoc(uid: string): Promise<DocumentSnapshot> {
  logger.info("requireMrUserDoc: called", {uid});
  logger.info("requireMrUserDoc: fetching Users doc", {uid});
  const userDoc = await getFirestore().collection("Users").doc(uid).get();
  logger.info("requireMrUserDoc: fetched Users doc", {uid, exists: userDoc.exists});
  if (!userDoc.exists || userDoc.data()?.role !== "mr") {
    throw new HttpsError("not-found", "No Medical Representative account found for that uid.");
  }
  return userDoc;
}

/** Throws if `username` is already taken by a different uid than `excludeUid`. */
async function requireUsernameAvailable(username: string, excludeUid?: string): Promise<void> {
  logger.info("requireUsernameAvailable: called", {username, excludeUid: excludeUid ?? null});
  logger.info("requireUsernameAvailable: querying Users by username", {username});
  const clash = await getFirestore().collection("Users").where("username", "==", username).limit(1).get();
  logger.info("requireUsernameAvailable: queried Users by username", {username, clashFound: !clash.empty});
  if (!clash.empty && clash.docs[0].id !== excludeUid) {
    throw new HttpsError("already-exists", "That username is already taken.");
  }
}

/**
 * Admin-only: creates a Medical Representative account plus their profile
 * (name, photo, area, designation, mobile). Runs with the Admin SDK so it
 * can create the Firebase Auth user, tag it with a `role: mr` custom claim,
 * and write its Firestore profile in one place without ever touching the
 * calling admin's own session (which is what happens if this were done with
 * the client Auth SDK instead).
 *
 * The MR's username is chosen by the admin (typically auto-suggested from
 * their name client-side, but editable) rather than derived here, so a
 * collision is rejected outright rather than silently appending a suffix —
 * same behavior as [updateEmployee]. A real email is required: it becomes
 * this account's actual sign-in email, so the MR logs in with it directly
 * and Firebase's native "forgot password" email works for them.
 */
export const createEmployee = onCall(async (request) => {
  logger.info("createEmployee: called", {
    username: (request.data as Partial<CreateEmployeeRequest>)?.username,
    email: (request.data as Partial<CreateEmployeeRequest>)?.email,
    designation: (request.data as Partial<CreateEmployeeRequest>)?.designation,
    areaName: (request.data as Partial<CreateEmployeeRequest>)?.areaName,
  });
  const adminUid = requireAdmin(request);

  const data = request.data as Partial<CreateEmployeeRequest>;
  const firstName = data.firstName?.trim() ?? "";
  const lastName = data.lastName?.trim() ?? "";
  const username = data.username?.trim().toLowerCase() ?? "";
  const password = data.password ?? "";
  const designation = data.designation?.trim() ?? "";
  const areaName = data.areaName?.trim() ?? "";
  const mobileNumber = data.mobileNumber?.trim() || null;
  const photoUrl = data.photoUrl?.trim() || null;
  const email = data.email?.trim().toLowerCase() || "";
  const dateOfBirth = data.dateOfBirth?.trim() || null;

  if (!firstName || !lastName) {
    throw new HttpsError("invalid-argument", "First and last name are required.");
  }
  if (!USERNAME_PATTERN.test(username)) {
    throw new HttpsError(
      "invalid-argument",
      "Username must be 3-32 characters: lowercase letters, numbers, dots, underscores or hyphens only."
    );
  }
  if (password.length < 6) {
    throw new HttpsError("invalid-argument", "Password must be at least 6 characters.");
  }
  if (!designation) {
    throw new HttpsError("invalid-argument", "Designation is required.");
  }
  if (!email) {
    throw new HttpsError("invalid-argument", "Email is required.");
  }
  if (!EMAIL_PATTERN.test(email)) {
    throw new HttpsError("invalid-argument", "That email address looks invalid.");
  }
  if (dateOfBirth && !DATE_OF_BIRTH_PATTERN.test(dateOfBirth)) {
    throw new HttpsError("invalid-argument", "Date of birth must be in YYYY-MM-DD format.");
  }

  await requireUsernameAvailable(username);
  const {designationId, managerId} = await resolveHierarchyFields(data.designationId, data.managerId);

  const displayName = `${firstName} ${lastName}`;
  const loginEmail = email;

  const auth = getAuth();
  let uid: string;
  try {
    logger.info("createEmployee: creating Auth user", {username, email});
    const userRecord = await auth.createUser({
      email: loginEmail,
      password,
      displayName,
      emailVerified: true,
    });
    uid = userRecord.uid;
    logger.info("createEmployee: created Auth user", {uid, username});
  } catch (error) {
    rethrowAuthError(error, "createEmployee: auth.createUser");
  }

  // From here on, the Auth user exists. If either of the following steps
  // fails, delete it rather than leaving an orphaned Auth account with no
  // Firestore profile (which would be invisible in "Manage Employees" but
  // still occupy the email/username and count against Auth quota).
  try {
    logger.info("createEmployee: setting custom user claims", {uid});
    await auth.setCustomUserClaims(uid, {role: "mr"});
    logger.info("createEmployee: set custom user claims", {uid});

    logger.info("createEmployee: writing Users profile doc", {uid, username});
    await getFirestore().collection("Users").doc(uid).set({
      username,
      firstName,
      lastName,
      displayName,
      designation,
      areaName,
      mobileNumber,
      photoUrl,
      email,
      dateOfBirth,
      designationId,
      managerId,
      role: "mr",
      disabled: false,
      // New accounts must complete the mandatory first-login profile step
      // (photo + name) before using the rest of the app — see
      // updateMyEmployeeProfile below and Employee.profileCompleted on the
      // Flutter side. Accounts that existed before this field shipped have
      // no value here at all, which the client treats as already complete,
      // so this never retroactively blocks anyone already using the app.
      profileCompleted: false,
      createdAt: FieldValue.serverTimestamp(),
      createdBy: adminUid,
    });
    logger.info("createEmployee: wrote Users profile doc", {uid, username});
  } catch (error) {
    logger.error("createEmployee: failed after Auth user was created, rolling back", {
      uid,
      username,
      error: String(error),
    });
    logger.info("createEmployee: rolling back by deleting Auth user", {uid});
    await auth.deleteUser(uid).catch((cleanupError) =>
      logger.error("createEmployee: rollback (auth.deleteUser) also failed", {uid, error: String(cleanupError)})
    );
    throw new HttpsError("internal", "Failed to finish setting up the new employee. Please try again.");
  }

  logger.info("createEmployee: succeeded", {uid, username});
  return {uid, username, loginEmail};
});

interface DeleteEmployeeRequest {
  uid: string;
}

/**
 * Admin-only: removes a Medical Representative's login and profile.
 * Only ever deletes accounts this system created (role === "mr" in their
 * Firestore profile), so a bad `uid` from a compromised client can't be
 * used to delete an arbitrary Firebase Auth user.
 */
export const deleteEmployee = onCall(async (request) => {
  logger.info("deleteEmployee: called", {uid: (request.data as Partial<DeleteEmployeeRequest>)?.uid});
  requireAdmin(request);

  const uid = (request.data as Partial<DeleteEmployeeRequest>).uid;
  if (!uid) {
    throw new HttpsError("invalid-argument", "uid is required.");
  }

  const userDoc = await requireMrUserDoc(uid);

  logger.info("deleteEmployee: deleting Auth user", {uid});
  await getAuth().deleteUser(uid);
  logger.info("deleteEmployee: deleted Auth user", {uid});

  logger.info("deleteEmployee: deleting Users profile doc", {uid});
  await userDoc.ref.delete();
  logger.info("deleteEmployee: deleted Users profile doc", {uid});

  logger.info("deleteEmployee: succeeded", {uid});
  return {success: true};
});

interface UpdateEmployeeRequest {
  uid: string;
  firstName: string;
  lastName: string;
  username: string;
  designation: string;
  areaName: string;
  mobileNumber?: string;
  photoUrl?: string;
  email: string;
  dateOfBirth?: string;
  designationId?: string;
  managerId?: string;
}

/**
 * Admin-only: edits a Medical Representative's profile, including their
 * username and email (their actual sign-in email — required, same as
 * creation). Unlike creation, the admin is typing the username explicitly
 * rather than it being derived from a name, so a collision is a rejection
 * ("pick another one") rather than an auto-appended suffix.
 */
export const updateEmployee = onCall(async (request) => {
  logger.info("updateEmployee: called", {
    uid: (request.data as Partial<UpdateEmployeeRequest>)?.uid,
    username: (request.data as Partial<UpdateEmployeeRequest>)?.username,
    email: (request.data as Partial<UpdateEmployeeRequest>)?.email,
  });
  requireAdmin(request);

  const data = request.data as Partial<UpdateEmployeeRequest>;
  const uid = data.uid ?? "";
  const firstName = data.firstName?.trim() ?? "";
  const lastName = data.lastName?.trim() ?? "";
  const username = data.username?.trim().toLowerCase() ?? "";
  const designation = data.designation?.trim() ?? "";
  const areaName = data.areaName?.trim() ?? "";
  const mobileNumber = data.mobileNumber?.trim() || null;
  const photoUrl = data.photoUrl?.trim() || null;
  const email = data.email?.trim().toLowerCase() || "";
  const dateOfBirth = data.dateOfBirth?.trim() || null;

  if (!uid) {
    throw new HttpsError("invalid-argument", "uid is required.");
  }
  if (!firstName || !lastName) {
    throw new HttpsError("invalid-argument", "First and last name are required.");
  }
  if (!USERNAME_PATTERN.test(username)) {
    throw new HttpsError(
      "invalid-argument",
      "Username must be 3-32 characters: lowercase letters, numbers, dots, underscores or hyphens only."
    );
  }
  if (!designation) {
    throw new HttpsError("invalid-argument", "Designation is required.");
  }
  if (!email) {
    throw new HttpsError("invalid-argument", "Email is required.");
  }
  if (!EMAIL_PATTERN.test(email)) {
    throw new HttpsError("invalid-argument", "That email address looks invalid.");
  }
  if (dateOfBirth && !DATE_OF_BIRTH_PATTERN.test(dateOfBirth)) {
    throw new HttpsError("invalid-argument", "Date of birth must be in YYYY-MM-DD format.");
  }

  const userDoc = await requireMrUserDoc(uid);

  if (username !== userDoc.data()?.username) {
    await requireUsernameAvailable(username, uid);
  }
  const {designationId, managerId} = await resolveHierarchyFields(data.designationId, data.managerId);

  const displayName = `${firstName} ${lastName}`;
  const loginEmail = email;
  const priorEmail = userDoc.data()?.email
    ? (userDoc.data()?.email as string)
    : usernameToEmail(userDoc.data()?.username as string);
  const priorDisplayName = userDoc.data()?.displayName as string | undefined;

  try {
    logger.info("updateEmployee: updating Auth user", {uid, email: loginEmail});
    await getAuth().updateUser(uid, {email: loginEmail, displayName});
    logger.info("updateEmployee: updated Auth user", {uid});
  } catch (error) {
    rethrowAuthError(error, "updateEmployee: auth.updateUser");
  }

  try {
    logger.info("updateEmployee: updating Users profile doc", {uid, username});
    await userDoc.ref.update({
      username,
      firstName,
      lastName,
      displayName,
      designation,
      areaName,
      mobileNumber,
      photoUrl,
      email,
      dateOfBirth,
      designationId,
      managerId,
    });
    logger.info("updateEmployee: updated Users profile doc", {uid, username});
  } catch (error) {
    logger.error("updateEmployee: Firestore write failed after Auth was already updated, rolling back", {
      uid,
      error: String(error),
    });
    // Firestore write failed after Auth was already updated — roll the Auth
    // record back so the two stores don't disagree on this employee's login.
    logger.info("updateEmployee: rolling back Auth user update", {uid});
    await getAuth()
      .updateUser(uid, {email: priorEmail, displayName: priorDisplayName})
      .catch((cleanupError) =>
        logger.error("updateEmployee: rollback (auth.updateUser) also failed", {uid, error: String(cleanupError)})
      );
    throw new HttpsError("internal", "Failed to save the employee profile. Please try again.");
  }

  logger.info("updateEmployee: succeeded", {uid, username});
  return {success: true, loginEmail};
});

interface ResetEmployeePasswordRequest {
  uid: string;
  newPassword: string;
}

/**
 * Admin-only: sets a new password for a Medical Representative directly.
 * This is the *only* "forgot password" path for an MR whose account has no
 * real email on file — their sign-in email is the synthetic
 * `mr-<username>@...` address (see adminAccess.ts), which nobody can receive
 * mail at, so Firebase's native "email a reset link" flow can't reach them.
 * (MRs who *do* have a real email use the native flow instead — see the
 * login screen's "Forgot password?" link — but this still works for them
 * too, as a fallback the admin can reach for directly.)
 */
export const resetEmployeePassword = onCall(async (request) => {
  logger.info("resetEmployeePassword: called", {uid: (request.data as Partial<ResetEmployeePasswordRequest>)?.uid});
  requireAdmin(request);

  const data = request.data as Partial<ResetEmployeePasswordRequest>;
  const uid = data.uid ?? "";
  const newPassword = data.newPassword ?? "";

  if (!uid) {
    throw new HttpsError("invalid-argument", "uid is required.");
  }
  if (newPassword.length < 6) {
    throw new HttpsError("invalid-argument", "Password must be at least 6 characters.");
  }

  await requireMrUserDoc(uid);

  logger.info("resetEmployeePassword: updating Auth user password", {uid});
  await getAuth().updateUser(uid, {password: newPassword});
  logger.info("resetEmployeePassword: updated Auth user password", {uid});

  logger.info("resetEmployeePassword: succeeded", {uid});
  return {success: true};
});

interface SetEmployeeStatusRequest {
  uid: string;
  disabled: boolean;
}

/**
 * Admin-only: suspends or reactivates a Medical Representative's account.
 * Suspending sets Firebase Auth's `disabled` flag, which immediately blocks
 * sign-in (surfaced to the MR as "This account has been disabled. Contact
 * your administrator.") without touching their profile or usage history —
 * unlike deleteEmployee, this is reversible.
 */
export const setEmployeeStatus = onCall(async (request) => {
  logger.info("setEmployeeStatus: called", {
    uid: (request.data as Partial<SetEmployeeStatusRequest>)?.uid,
    disabled: (request.data as Partial<SetEmployeeStatusRequest>)?.disabled,
  });
  requireAdmin(request);

  const data = request.data as Partial<SetEmployeeStatusRequest>;
  const uid = data.uid ?? "";
  const disabled = data.disabled;

  if (!uid) {
    throw new HttpsError("invalid-argument", "uid is required.");
  }
  if (typeof disabled !== "boolean") {
    throw new HttpsError("invalid-argument", "disabled must be a boolean.");
  }

  const userDoc = await requireMrUserDoc(uid);

  logger.info("setEmployeeStatus: updating Auth user disabled flag", {uid, disabled});
  await getAuth().updateUser(uid, {disabled});
  logger.info("setEmployeeStatus: updated Auth user disabled flag", {uid, disabled});

  try {
    logger.info("setEmployeeStatus: updating Users profile doc", {uid, disabled});
    await userDoc.ref.update({disabled});
    logger.info("setEmployeeStatus: updated Users profile doc", {uid, disabled});
  } catch (error) {
    logger.error("setEmployeeStatus: Firestore write failed after Auth was already flipped, rolling back", {
      uid,
      disabled,
      error: String(error),
    });
    // Firestore write failed after Auth was already flipped — roll the Auth
    // record back so a suspend/reactivate doesn't half-apply.
    logger.info("setEmployeeStatus: rolling back Auth user disabled flag", {uid, disabled: !disabled});
    await getAuth()
      .updateUser(uid, {disabled: !disabled})
      .catch((cleanupError) =>
        logger.error("setEmployeeStatus: rollback (auth.updateUser) also failed", {uid, error: String(cleanupError)})
      );
    throw new HttpsError("internal", "Failed to update this employee's status. Please try again.");
  }

  logger.info("setEmployeeStatus: succeeded", {uid, disabled});
  return {success: true};
});

interface UpdateMyEmployeeProfileRequest {
  firstName: string;
  lastName: string;
  mobileNumber?: string;
  photoUrl?: string;
  dateOfBirth?: string;
}

/**
 * Self-service: lets a signed-in Medical Representative edit their own
 * profile — but only the fields listed in [UpdateMyEmployeeProfileRequest].
 * Username, email, designation, areaName, disabled and role are never
 * touched here, matching the Profile screen's "can't change username and
 * email" requirement. Scoped to `request.auth.uid` (never a
 * client-supplied uid), and [requireMrUserDoc] throws "not-found" for any
 * caller without a `role: mr` profile — which includes the admin, who has
 * no `Users` doc at all and edits their own profile directly in
 * `AdminProfile/{uid}` instead (see firestore.rules).
 */
export const updateMyEmployeeProfile = onCall(async (request) => {
  logger.info("updateMyEmployeeProfile: called", {uid: request.auth?.uid});
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in to edit your profile.");
  }
  const uid = request.auth.uid;

  const data = request.data as Partial<UpdateMyEmployeeProfileRequest>;
  const firstName = data.firstName?.trim() ?? "";
  const lastName = data.lastName?.trim() ?? "";
  const mobileNumber = data.mobileNumber?.trim() || null;
  const photoUrl = data.photoUrl?.trim() || null;
  const dateOfBirth = data.dateOfBirth?.trim() || null;

  if (!firstName || !lastName) {
    throw new HttpsError("invalid-argument", "First and last name are required.");
  }
  if (dateOfBirth && !DATE_OF_BIRTH_PATTERN.test(dateOfBirth)) {
    throw new HttpsError("invalid-argument", "Date of birth must be in YYYY-MM-DD format.");
  }

  const userDoc = await requireMrUserDoc(uid);
  const displayName = `${firstName} ${lastName}`;

  logger.info("updateMyEmployeeProfile: updating Users profile doc", {uid});
  // Any self-service edit — including the mandatory first-login completion
  // screen, which calls this same endpoint — counts as having completed the
  // profile step.
  await userDoc.ref.update({
    firstName,
    lastName,
    displayName,
    mobileNumber,
    photoUrl,
    dateOfBirth,
    profileCompleted: true,
  });
  logger.info("updateMyEmployeeProfile: updated Users profile doc", {uid});

  return {success: true};
});

/**
 * Every notification this collection ever holds is created here, whenever
 * an MR's date of birth is set or changed (whether by the admin via
 * createEmployee/updateEmployee, or by the MR themselves via
 * updateMyEmployeeProfile above) — see AdminNotifications in
 * firestore.rules. Fires on the change itself, not annually.
 */
const ADMIN_NOTIFICATIONS_TOPIC = "admin-notifications";

export const onEmployeeDobChanged = onDocumentWritten("Users/{uid}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!after) return; // Employee deleted — nothing to notify about.

  const beforeDob = (before?.dateOfBirth as string | undefined) ?? null;
  const afterDob = (after.dateOfBirth as string | undefined) ?? null;
  if (beforeDob === afterDob || !afterDob) return;

  const uid = event.params.uid;
  const employeeName = (after.displayName as string | undefined) || "An employee";
  const message = `${employeeName} updated their date of birth to ${afterDob}.`;
  logger.info("onEmployeeDobChanged: date of birth changed, notifying admin", {uid, afterDob});

  await getFirestore().collection("AdminNotifications").add({
    employeeUid: uid,
    employeeName,
    message,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  await getMessaging().send({
    topic: ADMIN_NOTIFICATIONS_TOPIC,
    notification: {title: "Date of birth updated", body: message},
    data: {type: "admin_notification", employeeUid: uid},
    android: {priority: "high", notification: {channelId: "admin_notifications"}},
    apns: {headers: {"apns-priority": "10"}, payload: {aps: {contentAvailable: true, sound: "default"}}},
  });
  logger.info("onEmployeeDobChanged: finished", {uid});
});

/** Every device subscribes to this topic — see catalogUpdatesTopic in lib/core/notifications/push_notification_service.dart. */
const CATALOG_UPDATES_TOPIC = "catalog-updates";

/**
 * A single product/department edit in the admin app can fan out into many
 * Firestore writes (e.g. `renameDepartment` touches every product that
 * references it, in batches up to 500 — see product_remote_data_source.dart).
 * Without this guard, each of those writes would fire its own trigger below
 * and blast the whole device fleet with a burst of near-identical pushes for
 * one logical change. A short debounce window, enforced with a transaction
 * so concurrent trigger invocations can't both win it, collapses a burst
 * into a single notification.
 */
const NOTIFY_DEBOUNCE_MS = 15_000;

async function notifyCatalogUpdated(): Promise<void> {
  logger.info("notifyCatalogUpdated: called");
  const debounceRef = getFirestore().collection("CatalogMeta").doc("pushState");

  logger.info("notifyCatalogUpdated: running debounce transaction");
  const shouldSend = await getFirestore().runTransaction(async (tx) => {
    const doc = await tx.get(debounceRef);
    const lastSentAt = doc.data()?.lastSentAt as Timestamp | undefined;
    if (lastSentAt && Date.now() - lastSentAt.toMillis() < NOTIFY_DEBOUNCE_MS) {
      return false;
    }
    tx.set(debounceRef, {lastSentAt: FieldValue.serverTimestamp()});
    return true;
  });
  logger.info("notifyCatalogUpdated: ran debounce transaction", {shouldSend});
  if (!shouldSend) return;

  logger.info("notifyCatalogUpdated: sending FCM catalog-updates push", {topic: CATALOG_UPDATES_TOPIC});
  await getMessaging().send({
    topic: CATALOG_UPDATES_TOPIC,
    notification: {
      title: "Catalog updated",
      body: "New products or pricing are available. Syncing your catalog now.",
    },
    data: {type: "catalog_updated", updatedAt: new Date().toISOString()},
    android: {
      priority: "high",
      notification: {channelId: "catalog_updates"},
    },
    apns: {
      headers: {"apns-priority": "10"},
      payload: {aps: {contentAvailable: true, sound: "default"}},
    },
  });
  logger.info("notifyCatalogUpdated: sent FCM catalog-updates push", {topic: CATALOG_UPDATES_TOPIC});
}

/**
 * Broadcasts a catalog-update push (debounced, see [notifyCatalogUpdated])
 * whenever a product is created, edited, or deleted. Firestore rules already
 * restrict writes to this collection to the admin account, so any write seen
 * here is a legitimate catalog change.
 */
export const onProductsChanged = onDocumentWritten("Products/{productId}", async (event) => {
  logger.info("onProductsChanged: called", {productId: event.params.productId});
  await notifyCatalogUpdated();
  logger.info("onProductsChanged: finished", {productId: event.params.productId});
});

/** Same as [onProductsChanged], for department create/rename/delete. */
export const onDepartmentsChanged = onDocumentWritten("Department/{departmentDoc}", async (event) => {
  logger.info("onDepartmentsChanged: called", {departmentDoc: event.params.departmentDoc});
  await notifyCatalogUpdated();
  logger.info("onDepartmentsChanged: finished", {departmentDoc: event.params.departmentDoc});
});

/**
 * Sends a push to one specific person's device, looked up via
 * DeviceTokens/{uid} (see lib/data/remote/device_token_remote_data_source.dart
 * on the Flutter side). Unlike the topic-based pushes above (every device
 * shares catalog-updates/admin-notifications), a doctor-request-reviewed or
 * reminder-due push is only ever meant for one person, so it's sent to their
 * token directly rather than broadcast. Silently does nothing if that
 * person's device never registered a token (push permission denied, running
 * on an emulator, etc.) — these are all best-effort, never something a
 * workflow depends on completing.
 */
async function sendPushToUser(
  uid: string,
  notification: {title: string; body: string},
  data: Record<string, string>
): Promise<void> {
  logger.info("sendPushToUser: called", {uid});
  const tokenDoc = await getFirestore().collection("DeviceTokens").doc(uid).get();
  const token = tokenDoc.data()?.token as string | undefined;
  if (!token) {
    logger.info("sendPushToUser: no device token on file, skipping", {uid});
    return;
  }
  try {
    await getMessaging().send({
      token,
      notification,
      data,
      android: {priority: "high"},
      apns: {headers: {"apns-priority": "10"}, payload: {aps: {contentAvailable: true, sound: "default"}}},
    });
    logger.info("sendPushToUser: sent", {uid});
  } catch (error) {
    // A stale/unregistered token is expected (app uninstalled, token
    // rotated) — log and move on rather than failing whatever triggered
    // this push.
    logger.warn("sendPushToUser: send failed", {uid, error: String(error)});
  }
}

interface ReviewDoctorChangeRequestRequest {
  requestId: string;
  approve: boolean;
  reviewNote?: string;
}

/**
 * Admin-only: approves or rejects an MR's proposed doctor create/edit (see
 * DoctorChangeRequests in firestore.rules). Approving a `create` adds a new
 * Doctors doc from `proposedData`; approving an `update` merges it into the
 * existing doctor. Either way, the requesting MR is pushed a notification
 * once this resolves, via their own device token so only they see it.
 */
export const reviewDoctorChangeRequest = onCall(async (request) => {
  logger.info("reviewDoctorChangeRequest: called", {
    requestId: (request.data as Partial<ReviewDoctorChangeRequestRequest>)?.requestId,
    approve: (request.data as Partial<ReviewDoctorChangeRequestRequest>)?.approve,
  });
  const adminUid = requireAdmin(request);

  const data = request.data as Partial<ReviewDoctorChangeRequestRequest>;
  const requestId = data.requestId ?? "";
  const approve = data.approve;
  const reviewNote = data.reviewNote?.trim() || null;

  if (!requestId) {
    throw new HttpsError("invalid-argument", "requestId is required.");
  }
  if (typeof approve !== "boolean") {
    throw new HttpsError("invalid-argument", "approve must be a boolean.");
  }

  const firestore = getFirestore();
  const requestRef = firestore.collection("DoctorChangeRequests").doc(requestId);
  const requestDoc = await requestRef.get();
  if (!requestDoc.exists) {
    throw new HttpsError("not-found", "That request no longer exists.");
  }
  const requestData = requestDoc.data()!;
  if (requestData.status !== "pending") {
    throw new HttpsError("failed-precondition", "That request has already been reviewed.");
  }

  const proposedData = (requestData.proposedData ?? {}) as Record<string, unknown>;
  const type = requestData.type as string;
  const doctorId = requestData.doctorId as string | null;

  if (approve) {
    logger.info("reviewDoctorChangeRequest: approving", {requestId, type, doctorId});
    if (type === "update" && doctorId) {
      await firestore
        .collection("Doctors")
        .doc(doctorId)
        .set({...proposedData, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    } else {
      await firestore.collection("Doctors").add({...proposedData, updatedAt: FieldValue.serverTimestamp()});
    }
  }

  await requestRef.update({
    status: approve ? "approved" : "rejected",
    reviewNote,
    reviewedByUid: adminUid,
    reviewedAt: FieldValue.serverTimestamp(),
  });

  const requestedByUid = requestData.requestedByUid as string | undefined;
  const doctorName = (proposedData.name as string | undefined) || "A doctor";
  const action = type === "update" ? "update to" : "addition of";
  if (requestedByUid) {
    await sendPushToUser(
      requestedByUid,
      {
        title: approve ? "Doctor request approved" : "Doctor request rejected",
        body: approve
          ? `Your ${action} ${doctorName} was approved.`
          : `Your ${action} ${doctorName} was rejected.${reviewNote ? " " + reviewNote : ""}`,
      },
      {type: "doctor_request_reviewed", requestId, approved: String(approve)}
    );
  }

  logger.info("reviewDoctorChangeRequest: succeeded", {requestId, approve});
  return {success: true};
});

interface ReviewEntityChangeRequestRequest {
  requestId: string;
  approve: boolean;
  reviewNote?: string;
}

/**
 * Office-Admin-only (see [requireOfficeAdmin] — deliberately not
 * [requireAdmin], since agencies/pharmacies aren't limited to the hardcoded
 * admin allowlist): approves or rejects an MR's proposed new agency/
 * pharmacy (see EntityChangeRequests in firestore.rules). Approving writes a
 * new `Agencies`/`Pharmacies` doc from `proposedData`, keyed on
 * `entityType`. Mirrors [reviewDoctorChangeRequest] — the requesting MR is
 * pushed a notification once this resolves.
 */
export const reviewEntityChangeRequest = onCall(async (request) => {
  logger.info("reviewEntityChangeRequest: called", {
    requestId: (request.data as Partial<ReviewEntityChangeRequestRequest>)?.requestId,
    approve: (request.data as Partial<ReviewEntityChangeRequestRequest>)?.approve,
  });
  const reviewerUid = await requireOfficeAdmin(request);

  const data = request.data as Partial<ReviewEntityChangeRequestRequest>;
  const requestId = data.requestId ?? "";
  const approve = data.approve;
  const reviewNote = data.reviewNote?.trim() || null;

  if (!requestId) {
    throw new HttpsError("invalid-argument", "requestId is required.");
  }
  if (typeof approve !== "boolean") {
    throw new HttpsError("invalid-argument", "approve must be a boolean.");
  }

  const firestore = getFirestore();
  const requestRef = firestore.collection("EntityChangeRequests").doc(requestId);
  const requestDoc = await requestRef.get();
  if (!requestDoc.exists) {
    throw new HttpsError("not-found", "That request no longer exists.");
  }
  const requestData = requestDoc.data()!;
  if (requestData.status !== "pending") {
    throw new HttpsError("failed-precondition", "That request has already been reviewed.");
  }

  const proposedData = (requestData.proposedData ?? {}) as Record<string, unknown>;
  const entityType = requestData.entityType as string;
  const collectionName = entityType === "pharmacy" ? "Pharmacies" : "Agencies";

  if (approve) {
    logger.info("reviewEntityChangeRequest: approving", {requestId, entityType});
    await firestore.collection(collectionName).add({
      ...proposedData,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  await requestRef.update({
    status: approve ? "approved" : "rejected",
    reviewNote,
    reviewedByUid: reviewerUid,
    reviewedAt: FieldValue.serverTimestamp(),
  });

  const requestedByUid = requestData.requestedByUid as string | undefined;
  const entityName = (proposedData.name as string | undefined) || "A new entry";
  const entityLabel = entityType === "pharmacy" ? "pharmacy" : "agency";
  if (requestedByUid) {
    await sendPushToUser(
      requestedByUid,
      {
        title: approve ? "Request approved" : "Request rejected",
        body: approve
          ? `Your proposed ${entityLabel} "${entityName}" was approved.`
          : `Your proposed ${entityLabel} "${entityName}" was rejected.${reviewNote ? " " + reviewNote : ""}`,
      },
      {type: "entity_request_reviewed", requestId, approved: String(approve)}
    );
  }

  logger.info("reviewEntityChangeRequest: succeeded", {requestId, approve});
  return {success: true};
});

/**
 * Notifies the admin (via the existing AdminNotifications bell + push topic
 * — see onEmployeeDobChanged above) whenever an MR submits a new doctor
 * create/edit request, so the admin doesn't have to remember to go check for
 * pending requests themselves.
 */
export const onDoctorChangeRequestCreated = onDocumentWritten("DoctorChangeRequests/{requestId}", async (event) => {
  const before = event.data?.before;
  const after = event.data?.after?.data();
  if (before?.exists || !after) return; // Only fire on creation, not on review.

  const requestId = event.params.requestId;
  const requestedByName = (after.requestedByName as string | undefined) || "An MR";
  const type = after.type as string;
  const proposedData = after.proposedData as Record<string, unknown> | undefined;
  const doctorName = (proposedData?.name as string | undefined) || "a doctor";
  const message = `${requestedByName} ${type === "update" ? "proposed an edit to" : "proposed adding"} ${doctorName}.`;
  logger.info("onDoctorChangeRequestCreated: new request, notifying admin", {requestId});

  await getFirestore().collection("AdminNotifications").add({
    employeeUid: (after.requestedByUid as string | undefined) ?? "",
    employeeName: requestedByName,
    message,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  await getMessaging().send({
    topic: ADMIN_NOTIFICATIONS_TOPIC,
    notification: {title: "New doctor request", body: message},
    data: {type: "admin_notification", requestId},
    android: {priority: "high", notification: {channelId: "admin_notifications"}},
    apns: {headers: {"apns-priority": "10"}, payload: {aps: {contentAvailable: true, sound: "default"}}},
  });
  logger.info("onDoctorChangeRequestCreated: finished", {requestId});
});

/**
 * Runs every 15 minutes, pushing anyone whose reminder just came due.
 * Filtered to a single equality clause (`notified == false`) so this never
 * needs a composite Firestore index to deploy; the `dueAt <= now` check
 * happens in code, which is fine at this collection's expected scale (a
 * handful of open reminders per person at any time). `notified` guards
 * against double-sending on the next run for a reminder this already fired
 * for.
 */
export const sendDueReminders = onSchedule("every 15 minutes", async () => {
  logger.info("sendDueReminders: called");
  const firestore = getFirestore();
  const now = Timestamp.now();
  const notifiedPendingSnapshot = await firestore.collection("Reminders").where("notified", "==", false).get();

  const due = notifiedPendingSnapshot.docs.filter((doc) => {
    const dueAt = doc.data().dueAt as Timestamp | undefined;
    return dueAt !== undefined && dueAt.toMillis() <= now.toMillis();
  });

  if (due.length === 0) {
    logger.info("sendDueReminders: nothing due");
    return;
  }
  logger.info("sendDueReminders: found due reminders", {count: due.length});

  for (const doc of due) {
    const reminder = doc.data();
    const ownerUid = reminder.ownerUid as string | undefined;
    if (ownerUid && !reminder.completed) {
      await sendPushToUser(
        ownerUid,
        {title: "Reminder", body: (reminder.title as string) || "You have a reminder due."},
        {type: "reminder_due", reminderId: doc.id}
      );
    }
    await doc.ref.update({notified: true});
  }
  logger.info("sendDueReminders: finished", {count: due.length});
});

interface DispatchOrderRequest {
  orderId: string;
}

/**
 * `dispatch_orders`-gated: verifies the order is `approved`, decrements each
 * item's product stock (an atomic `FieldValue.increment` inside the same
 * transaction as the order's status flip, so a retried/duplicate call can
 * never double-decrement), and marks the order `dispatched`. Deliberately
 * does not block on insufficient stock — a negative `stockQuantity` is a
 * signal to reorder, not a hard error here.
 */
export const dispatchOrder = onCall(async (request) => {
  logger.info("dispatchOrder: called", {orderId: (request.data as Partial<DispatchOrderRequest>)?.orderId});
  await requirePermission(request, "dispatch_orders");

  const orderId = (request.data as Partial<DispatchOrderRequest>)?.orderId ?? "";
  if (!orderId) {
    throw new HttpsError("invalid-argument", "orderId is required.");
  }

  const firestore = getFirestore();
  const orderRef = firestore.collection("Orders").doc(orderId);

  await firestore.runTransaction(async (transaction) => {
    const orderDoc = await transaction.get(orderRef);
    if (!orderDoc.exists) {
      throw new HttpsError("not-found", "That order no longer exists.");
    }
    const order = orderDoc.data()!;
    if (order.status !== "approved") {
      throw new HttpsError("failed-precondition", "Only an approved order can be dispatched.");
    }

    const items = (order.items ?? []) as Array<{productId?: string; quantity?: number}>;
    for (const item of items) {
      if (!item.productId || !item.quantity) continue;
      const productRef = firestore.collection("Products").doc(item.productId);
      transaction.update(productRef, {stockQuantity: FieldValue.increment(-item.quantity)});
    }

    transaction.update(orderRef, {
      status: "dispatched",
      dispatchedByUid: request.auth!.uid,
      dispatchedAt: FieldValue.serverTimestamp(),
    });
  });

  logger.info("dispatchOrder: succeeded", {orderId});
  return {success: true};
});

interface GenerateInvoiceRequest {
  orderId: string;
}

/**
 * `manage_invoices`-gated: verifies the order is `dispatched`, assigns the
 * next sequential invoice number via a race-safe counter doc
 * (`Counters/invoiceNumber`), writes the `Invoices` doc, and marks the order
 * `invoiced` — all in one transaction so a retried/duplicate call can never
 * generate two invoices for the same order or skip/reuse a number.
 */
export const generateInvoice = onCall(async (request) => {
  logger.info("generateInvoice: called", {orderId: (request.data as Partial<GenerateInvoiceRequest>)?.orderId});
  await requirePermission(request, "manage_invoices");

  const orderId = (request.data as Partial<GenerateInvoiceRequest>)?.orderId ?? "";
  if (!orderId) {
    throw new HttpsError("invalid-argument", "orderId is required.");
  }

  const firestore = getFirestore();
  const orderRef = firestore.collection("Orders").doc(orderId);
  const counterRef = firestore.collection("Counters").doc("invoiceNumber");
  const invoiceRef = firestore.collection("Invoices").doc();

  await firestore.runTransaction(async (transaction) => {
    const [orderDoc, counterDoc] = await Promise.all([transaction.get(orderRef), transaction.get(counterRef)]);
    if (!orderDoc.exists) {
      throw new HttpsError("not-found", "That order no longer exists.");
    }
    const order = orderDoc.data()!;
    if (order.status !== "dispatched") {
      throw new HttpsError("failed-precondition", "Only a dispatched order can be invoiced.");
    }

    const nextNumber = ((counterDoc.data()?.value as number | undefined) ?? 0) + 1;
    const invoiceNumber = `INV-${String(nextNumber).padStart(6, "0")}`;

    transaction.set(counterRef, {value: nextNumber});
    transaction.set(invoiceRef, {
      orderId,
      invoiceNumber,
      agencyId: order.agencyId,
      agencyName: order.agencyName,
      items: order.items,
      totalValue: order.totalValue,
      issuedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(orderRef, {status: "invoiced", invoiceId: invoiceRef.id});
  });

  logger.info("generateInvoice: succeeded", {orderId});
  return {success: true};
});
