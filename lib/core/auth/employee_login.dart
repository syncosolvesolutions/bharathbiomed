import 'package:flutter/foundation.dart';

import '../tenant/tenant_config.dart';

/// Medical Representatives log in with a plain username (e.g. `rajesh_kumar`),
/// not a real email — Firebase Auth still requires an email-shaped identifier
/// under the hood. See [TenantConfig.employeeEmailDomain] for how this is
/// derived (compile-time, from the tenant's Firebase project id) rather than
/// hardcoded.
String get employeeEmailDomain => currentTenant.employeeEmailDomain;

/// Resolves whatever the user typed in the login field into the identifier
/// Firebase Auth actually expects: a real email is passed through as-is (the
/// admin's account), while a bare username is turned into its synthetic
/// `mr-<username>@...` email.
String resolveLoginEmail(String input) {
  debugPrint('employee_login.resolveLoginEmail: resolving login identifier for input=$input');
  final trimmed = input.trim();
  if (trimmed.contains('@')) return trimmed;
  return 'mr-${trimmed.toLowerCase()}@$employeeEmailDomain';
}
