import '../tenant/tenant_config.dart';

/// Emails allowed to see and use the admin (catalog CRUD / employee
/// management) section of the app — sourced from the active tenant's
/// config (see tenant_config.dart), not hardcoded here.
///
/// This only controls what the UI shows — the copies in
/// functions/src/adminAccess.ts and firestore.rules are what actually
/// enforce it server-side. All three are generated from the same
/// `tenants/<tenantId>/tenant.json` by scripts/apply_tenant.dart; edit the
/// json and re-run that script, don't hand-edit any of the three.
final Set<String> adminEmails = currentTenant.adminEmails;

bool isAdminEmail(String? email) => email != null && adminEmails.contains(email);
