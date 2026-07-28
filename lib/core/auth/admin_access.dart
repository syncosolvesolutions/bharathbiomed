/// Emails allowed to see and use the admin (catalog CRUD / employee
/// management) section of the app.
///
/// This only controls what the UI shows — the copies in
/// functions/src/adminAccess.ts and firestore.rules are what actually
/// enforce it server-side. Keep all three in sync.
const adminEmails = {
  'bharathbiomedpharma@gmail.com',
  'sudhakar.gotte@bharathbiomedpharma.com',
};

bool isAdminEmail(String? email) => email != null && adminEmails.contains(email);
