/// Medical Representatives log in with a plain username (e.g. `rajesh_kumar`),
/// not a real email — Firebase Auth still requires an email-shaped identifier
/// under the hood, so this mirrors functions/src/adminAccess.ts's
/// `usernameToEmail` exactly. Keep both in sync.
const employeeEmailDomain = 'bharathbiomedpharma-6c6c3.firebaseapp.com';

/// Resolves whatever the user typed in the login field into the identifier
/// Firebase Auth actually expects: a real email is passed through as-is (the
/// admin's account), while a bare username is turned into its synthetic
/// `mr-<username>@...` email.
String resolveLoginEmail(String input) {
  final trimmed = input.trim();
  if (trimmed.contains('@')) return trimmed;
  return 'mr-${trimmed.toLowerCase()}@$employeeEmailDomain';
}
