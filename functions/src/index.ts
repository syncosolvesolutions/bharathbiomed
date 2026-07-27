import {DocumentSnapshot, FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getMessaging} from "firebase-admin/messaging";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onDocumentWritten} from "firebase-functions/v2/firestore";

import {requireAdmin, usernameToEmail} from "./adminAccess";

initializeApp();

const USERNAME_PATTERN = /^[a-z0-9._-]{3,32}$/;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

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
}

/** Turns an Auth-SDK error into the right HttpsError, or rethrows it unchanged. */
function rethrowAuthError(error: unknown): never {
  const code = (error as {code?: string}).code;
  if (code === "auth/email-already-exists") {
    throw new HttpsError("already-exists", "That email or username is already taken.");
  }
  if (code === "auth/invalid-email") {
    throw new HttpsError("invalid-argument", "That email address looks invalid.");
  }
  throw error;
}

/** Loads Users/{uid} and throws unless it's a profile this system created (role === "mr"). */
async function requireMrUserDoc(uid: string): Promise<DocumentSnapshot> {
  const userDoc = await getFirestore().collection("Users").doc(uid).get();
  if (!userDoc.exists || userDoc.data()?.role !== "mr") {
    throw new HttpsError("not-found", "No Medical Representative account found for that uid.");
  }
  return userDoc;
}

/** Throws if `username` is already taken by a different uid than `excludeUid`. */
async function requireUsernameAvailable(username: string, excludeUid?: string): Promise<void> {
  const clash = await getFirestore().collection("Users").where("username", "==", username).limit(1).get();
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

  await requireUsernameAvailable(username);

  const displayName = `${firstName} ${lastName}`;
  const loginEmail = email;

  const auth = getAuth();
  let uid: string;
  try {
    const userRecord = await auth.createUser({
      email: loginEmail,
      password,
      displayName,
      emailVerified: true,
    });
    uid = userRecord.uid;
  } catch (error) {
    rethrowAuthError(error);
  }

  // From here on, the Auth user exists. If either of the following steps
  // fails, delete it rather than leaving an orphaned Auth account with no
  // Firestore profile (which would be invisible in "Manage Employees" but
  // still occupy the email/username and count against Auth quota).
  try {
    await auth.setCustomUserClaims(uid, {role: "mr"});

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
      role: "mr",
      disabled: false,
      createdAt: FieldValue.serverTimestamp(),
      createdBy: adminUid,
    });
  } catch (error) {
    await auth.deleteUser(uid).catch(() => undefined);
    throw new HttpsError("internal", "Failed to finish setting up the new employee. Please try again.");
  }

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
  requireAdmin(request);

  const uid = (request.data as Partial<DeleteEmployeeRequest>).uid;
  if (!uid) {
    throw new HttpsError("invalid-argument", "uid is required.");
  }

  const userDoc = await requireMrUserDoc(uid);
  await getAuth().deleteUser(uid);
  await userDoc.ref.delete();

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
}

/**
 * Admin-only: edits a Medical Representative's profile, including their
 * username and email (their actual sign-in email — required, same as
 * creation). Unlike creation, the admin is typing the username explicitly
 * rather than it being derived from a name, so a collision is a rejection
 * ("pick another one") rather than an auto-appended suffix.
 */
export const updateEmployee = onCall(async (request) => {
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

  const userDoc = await requireMrUserDoc(uid);

  if (username !== userDoc.data()?.username) {
    await requireUsernameAvailable(username, uid);
  }

  const displayName = `${firstName} ${lastName}`;
  const loginEmail = email;
  const priorEmail = userDoc.data()?.email
    ? (userDoc.data()?.email as string)
    : usernameToEmail(userDoc.data()?.username as string);
  const priorDisplayName = userDoc.data()?.displayName as string | undefined;

  try {
    await getAuth().updateUser(uid, {email: loginEmail, displayName});
  } catch (error) {
    rethrowAuthError(error);
  }

  try {
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
    });
  } catch (error) {
    // Firestore write failed after Auth was already updated — roll the Auth
    // record back so the two stores don't disagree on this employee's login.
    await getAuth()
      .updateUser(uid, {email: priorEmail, displayName: priorDisplayName})
      .catch(() => undefined);
    throw new HttpsError("internal", "Failed to save the employee profile. Please try again.");
  }

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
  await getAuth().updateUser(uid, {password: newPassword});

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
  await getAuth().updateUser(uid, {disabled});

  try {
    await userDoc.ref.update({disabled});
  } catch (error) {
    // Firestore write failed after Auth was already flipped — roll the Auth
    // record back so a suspend/reactivate doesn't half-apply.
    await getAuth()
      .updateUser(uid, {disabled: !disabled})
      .catch(() => undefined);
    throw new HttpsError("internal", "Failed to update this employee's status. Please try again.");
  }

  return {success: true};
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
  const debounceRef = getFirestore().collection("CatalogMeta").doc("pushState");

  const shouldSend = await getFirestore().runTransaction(async (tx) => {
    const doc = await tx.get(debounceRef);
    const lastSentAt = doc.data()?.lastSentAt as Timestamp | undefined;
    if (lastSentAt && Date.now() - lastSentAt.toMillis() < NOTIFY_DEBOUNCE_MS) {
      return false;
    }
    tx.set(debounceRef, {lastSentAt: FieldValue.serverTimestamp()});
    return true;
  });
  if (!shouldSend) return;

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
}

/**
 * Broadcasts a catalog-update push (debounced, see [notifyCatalogUpdated])
 * whenever a product is created, edited, or deleted. Firestore rules already
 * restrict writes to this collection to the admin account, so any write seen
 * here is a legitimate catalog change.
 */
export const onProductsChanged = onDocumentWritten("Products/{productId}", async () => {
  await notifyCatalogUpdated();
});

/** Same as [onProductsChanged], for department create/rename/delete. */
export const onDepartmentsChanged = onDocumentWritten("Department/{departmentDoc}", async () => {
  await notifyCatalogUpdated();
});
