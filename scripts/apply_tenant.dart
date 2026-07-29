// Regenerates every file that must vary per tenant from a single
// `tenants/<tenantId>/tenant.json`, so branding/admin-identity values are
// never hand-typed in more than one place. Run after editing a tenant's
// json, or when onboarding a new tenant (see scripts/new_tenant.sh, which
// calls this as one step of a full onboarding run).
//
// Usage: dart run scripts/apply_tenant.dart <tenantId>
//
// Regenerates:
//   - lib/core/tenant/tenant_config.dart      (the Dart-side single source
//     of truth every screen/util in lib/ reads from)
//   - functions/src/generatedTenantConfig.ts  (the Cloud-Functions-side
//     twin of the same tenant.json — a fully generated file, no markers)
//   - functions/src/adminAccess.ts            (ADMIN_EMAILS, between the
//     TENANT-ADMIN-EMAILS markers)
//   - firestore.rules                         (isAdmin()'s email list,
//     between the TENANT-ADMIN-EMAILS markers)
//   - docs/TERMS_AND_CONDITIONS.md             (rendered from
//   - docs/PRIVACY_POLICY.md                    lib/features/legal/legal_content.dart's
//                                                templates, not a separate copy)
//
// Deliberately does NOT touch branding assets (logo/icon/splash), Firebase
// project wiring (firebase_options.dart, google-services.json,
// GoogleService-Info.plist), or Android/iOS application/bundle id — those
// are handled by scripts/new_tenant.sh, since they need `flutterfire
// configure` / `flutter_launcher_icons` / `flutter_native_splash`, not just
// text substitution.

import 'dart:convert';
import 'dart:io';

import 'package:bharathbiomedpharma/core/tenant/tenant_config.dart';
import 'package:bharathbiomedpharma/features/legal/legal_content.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run scripts/apply_tenant.dart <tenantId>');
    exit(64);
  }
  final tenantId = args.first;
  final tenantFile = File('tenants/$tenantId/tenant.json');
  if (!tenantFile.existsSync()) {
    stderr.writeln('No such tenant config: ${tenantFile.path}');
    exit(66);
  }

  final json = jsonDecode(await tenantFile.readAsString()) as Map<String, dynamic>;
  final tenant = _tenantConfigFromJson(json);

  _writeTenantConfigDart(tenant);
  _writeFunctionsGeneratedConfig(tenant);
  _replaceMarkedBlock(
    file: File('functions/src/adminAccess.ts'),
    startMarker: '// TENANT-ADMIN-EMAILS:START',
    endMarker: '// TENANT-ADMIN-EMAILS:END',
    body: tenant.adminEmails.map((e) => '  "$e",').join('\n'),
  );
  _replaceMarkedBlock(
    file: File('firestore.rules'),
    startMarker: '// TENANT-ADMIN-EMAILS:START',
    endMarker: '// TENANT-ADMIN-EMAILS:END',
    // No trailing comma before the closing `]` — Firestore's rules grammar
    // doesn't accept one in a list literal, unlike the TypeScript array above.
    body: tenant.adminEmails.map((e) => "        '$e'").join(',\n'),
  );
  await _writeLegalMarkdown(
    file: File('docs/TERMS_AND_CONDITIONS.md'),
    title: 'Terms & Conditions',
    sections: termsAndConditionsSections(tenant),
  );
  await _writeLegalMarkdown(
    file: File('docs/PRIVACY_POLICY.md'),
    title: 'Privacy Policy',
    sections: privacyPolicySections(tenant),
  );

  stdout.writeln('Applied tenant "$tenantId" (${tenant.appName}).');
  stdout.writeln('Still manual: branding assets, Firebase project wiring, '
      'Android/iOS app id — see scripts/new_tenant.sh.');
}

TenantConfig _tenantConfigFromJson(Map<String, dynamic> json) {
  return TenantConfig(
    tenantId: json['tenantId'] as String,
    appName: json['appName'] as String,
    legalCompanyName: json['legalCompanyName'] as String,
    primaryColorValue: int.parse((json['primaryColorHex'] as String).substring(2), radix: 16) | 0xFF000000,
    adminEmails: Set<String>.from(json['adminEmails'] as List),
    supportEmail: json['supportEmail'] as String,
    defaultPassword: json['defaultPassword'] as String,
    defaultCountryCode: json['defaultCountryCode'] as String,
    jurisdiction: json['jurisdiction'] as String,
    designationLadder: List<String>.from(json['designationLadder'] as List),
    firebaseProjectId: json['firebaseProjectId'] as String,
    ucpmpAnnualLimitPerDoctor: (json['ucpmpAnnualLimitPerDoctor'] as num).toDouble(),
    taxLabel: json['taxLabel'] as String,
    taxRatePercent: (json['taxRatePercent'] as num).toDouble(),
    paymentTermsDays: (json['paymentTermsDays'] as num).toInt(),
  );
}

/// The Cloud-Functions-side twin of [TenantConfig]'s tax fields — a fully
/// generated file (unlike adminAccess.ts/firestore.rules, which only have a
/// marked sub-block regenerated) since every value in it comes from
/// tenant.json with nothing hand-written alongside.
void _writeFunctionsGeneratedConfig(TenantConfig tenant) {
  final content = '''
// GENERATED for this build from tenants/${tenant.tenantId}/tenant.json by
// scripts/apply_tenant.dart — do not hand-edit; edit the tenant's
// tenant.json and re-run that script. Mirrors the tax/payment fields on
// lib/core/tenant/tenant_config.dart's TenantConfig (Cloud Functions can't
// import that Dart file, so both are generated separately from the same
// source).

export const TAX_LABEL = "${tenant.taxLabel}";
export const TAX_RATE_PERCENT = ${tenant.taxRatePercent};
export const PAYMENT_TERMS_DAYS = ${tenant.paymentTermsDays};
''';
  File('functions/src/generatedTenantConfig.ts').writeAsStringSync(content);
}

void _writeTenantConfigDart(TenantConfig tenant) {
  final adminEmailsLiteral = tenant.adminEmails.map((e) => "    '$e',").join('\n');
  final ladderLiteral = tenant.designationLadder.map((d) => "    '$d',").join('\n');
  final content = '''
/// Every value that varies from one pharma company's deployment of this app
/// to another: branding, admin identity, and business defaults. This is the
/// single Dart-side source of truth for those values — every screen/util
/// that used to hardcode a company-specific literal reads it from
/// [currentTenant] instead.
///
/// GENERATED for this build from `tenants/${tenant.tenantId}/tenant.json` by
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
  String get employeeEmailDomain => '\$firebaseProjectId.firebaseapp.com';

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
  tenantId: '${tenant.tenantId}',
  appName: '${tenant.appName}',
  legalCompanyName: '${tenant.legalCompanyName}',
  primaryColorValue: 0x${tenant.primaryColorValue.toRadixString(16).toUpperCase()},
  adminEmails: {
$adminEmailsLiteral
  },
  supportEmail: '${tenant.supportEmail}',
  defaultPassword: '${tenant.defaultPassword}',
  defaultCountryCode: '${tenant.defaultCountryCode}',
  jurisdiction: '${tenant.jurisdiction}',
  designationLadder: [
$ladderLiteral
  ],
  firebaseProjectId: '${tenant.firebaseProjectId}',
  ucpmpAnnualLimitPerDoctor: ${tenant.ucpmpAnnualLimitPerDoctor},
  taxLabel: '${tenant.taxLabel}',
  taxRatePercent: ${tenant.taxRatePercent},
  paymentTermsDays: ${tenant.paymentTermsDays},
);
''';
  File('lib/core/tenant/tenant_config.dart').writeAsStringSync(content);
}

void _replaceMarkedBlock({
  required File file,
  required String startMarker,
  required String endMarker,
  required String body,
}) {
  final content = file.readAsStringSync();
  final start = content.indexOf(startMarker);
  final end = content.indexOf(endMarker);
  if (start == -1 || end == -1 || end < start) {
    throw StateError('Marker pair $startMarker/$endMarker not found in ${file.path}');
  }
  // Preserve whatever indentation preceded the end marker in the original
  // file, so the regenerated block still lines up visually.
  final lineStart = content.lastIndexOf('\n', end) + 1;
  final endIndent = content.substring(lineStart, end);
  final before = content.substring(0, start + startMarker.length);
  final after = content.substring(end);
  file.writeAsStringSync('$before\n$body\n$endIndent$after');
}

Future<void> _writeLegalMarkdown({
  required File file,
  required String title,
  required List<LegalSection> sections,
}) async {
  final buffer = StringBuffer()
    ..writeln('# $title')
    ..writeln()
    ..writeln('_Last updated: ${legalLastUpdated}_')
    ..writeln();
  for (final section in sections) {
    buffer
      ..writeln('## ${section.heading}')
      ..writeln();
    for (final paragraph in section.paragraphs) {
      buffer
        ..writeln(paragraph)
        ..writeln();
    }
    for (final bullet in section.bullets) {
      buffer.writeln('- $bullet');
    }
    if (section.bullets.isNotEmpty) buffer.writeln();
  }
  await file.writeAsString(buffer.toString());
}
