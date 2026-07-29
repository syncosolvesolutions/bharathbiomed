/// Every value that varies from one pharma company's deployment of this app
/// to another: branding, admin identity, and business defaults. This is the
/// single Dart-side source of truth for those values — every screen/util
/// that used to hardcode a company-specific literal reads it from
/// [currentTenant] instead.
///
/// GENERATED for this build from `tenants/bharathbiomed/tenant.json` by
/// `scripts/apply_tenant.dart` — do not hand-edit this file's [currentTenant]
/// values directly; edit the tenant's `tenant.json` and re-run that script,
/// which also regenerates the two files that can't `import` Dart
/// (`functions/src/adminAccess.ts`'s `ADMIN_EMAILS`, `firestore.rules`'
/// `isAdmin()`) and `docs/TERMS_AND_CONDITIONS.md` / `docs/PRIVACY_POLICY.md`
/// from the same source, so none of those can drift out of sync by hand.
class TenantConfig {
  const TenantConfig({
    required this.tenantId,
    required this.appName,
    required this.legalCompanyName,
    required this.primaryColorValue,
    required this.adminEmails,
    required this.supportEmail,
    required this.defaultPassword,
    required this.defaultCountryCode,
    required this.jurisdiction,
    required this.designationLadder,
    required this.firebaseProjectId,
    required this.ucpmpAnnualLimitPerDoctor,
    required this.taxLabel,
    required this.taxRatePercent,
    required this.paymentTermsDays,
  });

  final String tenantId;

  /// Shown as the app title, catalog AppBar title, and in credential-share
  /// messages sent to new MRs.
  final String appName;

  /// Used in legal-document copy (Terms & Conditions / Privacy Policy) —
  /// kept separate from [appName] since a company's registered legal name
  /// can differ from its product/app name.
  final String legalCompanyName;

  /// ARGB color value (e.g. `0xFF3470B2`) — kept as a plain int rather than
  /// a `Color` so this file has no Flutter dependency and can be imported by
  /// plain-Dart tooling (scripts/apply_tenant.dart). Wrapped in `Color(...)`
  /// at the point of use — see AppTheme.primary.
  final int primaryColorValue;

  /// Emails allowed into the admin section. Mirrored server-side in
  /// `functions/src/adminAccess.ts` and `firestore.rules` — those are what
  /// actually enforce it; this copy only controls what the UI shows. All
  /// three are generated from the same `tenant.json`, see the file-level
  /// doc comment above.
  final Set<String> adminEmails;

  /// Contact address shown in the in-app Terms & Conditions / Privacy
  /// Policy for legal/data-deletion questions.
  final String supportEmail;

  /// Prefilled when an admin creates a new MR or resets one's password —
  /// still editable per-person, this is just the starting suggestion.
  final String defaultPassword;

  /// ISO country calling code (no leading `+`), used to build a WhatsApp
  /// deep link from a bare 10-digit mobile number when none is present.
  final String defaultCountryCode;

  /// Governing-law jurisdiction named in the Terms & Conditions.
  final String jurisdiction;

  /// Seed data for Manage Designations the first time an admin opens it —
  /// purely a starting point, freely editable afterward.
  final List<String> designationLadder;

  /// This tenant's Firebase project id, used to derive
  /// [employeeEmailDomain] below without hand-typing it a second time.
  final String firebaseProjectId;

  /// Synthetic email domain for Medical Representative accounts (they log
  /// in with a plain username, not a real email — see
  /// lib/core/auth/employee_login.dart). Derived from [firebaseProjectId]
  /// at compile time (not read from `Firebase.app()` at runtime) so this
  /// stays a pure value usable in plain unit tests without initializing
  /// Firebase. Mirrors functions/src/adminAccess.ts's
  /// `EMPLOYEE_EMAIL_DOMAIN`, which derives the same value server-side from
  /// the deployed project id — both must keep resolving to the same domain.
  String get employeeEmailDomain => '$firebaseProjectId.firebaseapp.com';

  /// Maximum cumulative value (in whatever currency this tenant operates
  /// in — there's no currency field yet, see the "not built" note in
  /// `features/compliance/SKILL.md`) an MR may give one doctor per
  /// calendar year in gifts/sponsorships/hospitality before
  /// `ComplianceDashboardScreen` flags that doctor as over the UCPMP
  /// limit. `0` (this tenant's default) means "flag any nonzero value" —
  /// India's UCPMP guidance is that prescribers generally shouldn't
  /// receive gifts at all, so a zero default errs toward flagging
  /// everything rather than silently allowing an unconfigured limit.
  /// Logging is never blocked by this limit — it's a dashboard flag, not a
  /// hard stop, since the whole point of the log is to make what actually
  /// happened visible and auditable.
  final double ucpmpAnnualLimitPerDoctor;

  /// Shown as the tax line label on invoices (e.g. "GST", "VAT", "Sales
  /// Tax") — see `functions/src/generatedTenantConfig.ts` for the
  /// Cloud-Functions-side twin of this and [taxRatePercent] (Cloud
  /// Functions can't import this Dart file, so both are generated
  /// separately from the same `tenant.json` by `scripts/apply_tenant.dart`).
  final String taxLabel;

  /// A single tenant-wide tax rate applied to every order's subtotal when
  /// `generateInvoice` runs. Real GST has multiple rate slabs per product
  /// HSN code — this app has no per-product tax-rate field, so this is a
  /// deliberate simplification, not a full tax engine. A tenant that
  /// genuinely needs per-product rates would need that field added to
  /// `Product` first.
  final double taxRatePercent;

  /// Days after `Invoice.issuedAt` before an unpaid/partially-paid invoice
  /// is considered overdue — see `Invoice.isOverdue`.
  final int paymentTermsDays;
}

const currentTenant = TenantConfig(
  tenantId: 'bharathbiomed',
  appName: 'Bharath Biomed Pharma',
  legalCompanyName: 'Bharath Biomed Pharma',
  primaryColorValue: 0xFF3470B2,
  adminEmails: {
    'bharathbiomedpharma@gmail.com',
    'sudhakar.gotte@bharathbiomedpharma.com',
  },
  supportEmail: 'swapna.balugu@gmail.com',
  defaultPassword: 'Bharathbio@2026',
  defaultCountryCode: '91',
  jurisdiction: 'India',
  designationLadder: [
    'Medical Representative',
    'Senior Medical Representative',
    'Area Business Manager',
    'Regional Business Manager',
    'Zonal Business Manager',
  ],
  firebaseProjectId: 'bharathbiomedpharma-6c6c3',
  ucpmpAnnualLimitPerDoctor: 0.0,
  taxLabel: 'GST',
  taxRatePercent: 12.0,
  paymentTermsDays: 30,
);
