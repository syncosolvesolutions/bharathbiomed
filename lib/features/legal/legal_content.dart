import '../../core/tenant/tenant_config.dart';

/// One section of a legal document: a heading plus paragraphs and/or a
/// bullet list. Kept as structured data (not markdown) so it renders
/// natively without needing a markdown-parsing dependency, and works fully
/// offline since it's bundled in the app rather than fetched or loaded from
/// an external URL.
///
/// This content is the single template for docs/TERMS_AND_CONDITIONS.md and
/// docs/PRIVACY_POLICY.md too — those are regenerated from
/// [termsAndConditionsSections]/[privacyPolicySections] by
/// scripts/apply_tenant.dart, not hand-edited separately.
class LegalSection {
  const LegalSection({required this.heading, this.paragraphs = const [], this.bullets = const []});

  final String heading;
  final List<String> paragraphs;
  final List<String> bullets;
}

const String legalLastUpdated = '2026-07-27';

/// Terms & Conditions content for [tenant] — every company-name/jurisdiction/
/// contact-email mention is sourced from [TenantConfig] instead of hardcoded,
/// so the same template serves every tenant's build.
List<LegalSection> termsAndConditionsSections([TenantConfig tenant = currentTenant]) => [
      LegalSection(
        heading: '1. Acceptance of these terms',
        paragraphs: [
          'This app is an internal business tool provided by ${tenant.legalCompanyName} '
              '("we", "us", "our company") to our field sales staff and administrators. '
              'By signing in or using this app, you agree to these Terms & Conditions '
              'and to our Privacy Policy.',
        ],
      ),
      const LegalSection(
        heading: '2. Purpose of this app',
        paragraphs: [
          'This app exists to let our sales team browse and present our product '
              'catalog to customers, online or offline, and to let administrators '
              'manage that catalog and manage Medical Representative accounts. It is '
              'not a public consumer app and is not intended for use by anyone outside '
              'our company.',
        ],
      ),
      const LegalSection(
        heading: '3. Your account and credentials',
        paragraphs: [
          'Medical Representative accounts are created for you by an administrator, '
              'not self-registered. You are responsible for keeping your username/email '
              'and password confidential, and for all activity that happens under your '
              'account. Do not share your login with anyone else.',
          'If you forget your password, use the "Forgot password?" link on the '
              'login screen (if you have a real email on file) or contact your '
              'administrator, who can reset it for you.',
        ],
      ),
      LegalSection(
        heading: '4. Acceptable use',
        paragraphs: [
          'Use this app only for legitimate business purposes connected to your role '
              'at ${tenant.legalCompanyName}. You agree not to attempt to access, modify, or '
              'delete data you\'re not authorized to, misuse the admin features if you '
              'are not an administrator, or use the app in any way that violates '
              'applicable law.',
        ],
      ),
      const LegalSection(
        heading: '5. Monitoring and data collection',
        paragraphs: [
          'As part of managing our field sales operations, the app records certain '
              'usage information for Medical Representative accounts — including when '
              'the app is opened, how long it\'s used, and the device\'s location at '
              'the time the app is opened — visible to administrators. Full details of '
              'what is collected and why are in our Privacy Policy, which you should '
              'read alongside these terms.',
        ],
      ),
      LegalSection(
        heading: '6. Intellectual property',
        paragraphs: [
          'The product catalog, images, descriptions, branding, and all other '
              'content made available through this app belong to ${tenant.legalCompanyName} '
              'or its licensors. You may use this content only for its intended '
              'purpose (presenting our products) and not reproduce, redistribute, or '
              'repurpose it outside of that.',
        ],
      ),
      const LegalSection(
        heading: '7. Termination of access',
        paragraphs: [
          'We may suspend or remove your access to this app at any time, for any '
              'reason, including but not limited to end of employment, misuse of the '
              'app, or a business decision to discontinue it.',
        ],
      ),
      const LegalSection(
        heading: '8. Disclaimer of warranties',
        paragraphs: [
          'This app is provided "as is". While we aim to keep the catalog accurate '
              'and the app functioning reliably, we don\'t guarantee it will always be '
              'error-free, uninterrupted, or available, including in areas with no '
              'network connectivity.',
        ],
      ),
      LegalSection(
        heading: '9. Limitation of liability',
        paragraphs: [
          'To the extent permitted by law, ${tenant.legalCompanyName} is not liable for '
              'indirect, incidental, or consequential damages arising from your use of '
              'this app, beyond what is required by applicable employment or consumer '
              'protection law.',
        ],
      ),
      LegalSection(
        heading: '10. Governing law',
        paragraphs: [
          'These terms are governed by the laws of ${tenant.jurisdiction}, without regard to its '
              'conflict-of-law principles.',
        ],
      ),
      const LegalSection(
        heading: '11. Changes to these terms',
        paragraphs: [
          'We may update these terms from time to time. Continued use of the app '
              'after a change means you accept the updated terms.',
        ],
      ),
      LegalSection(
        heading: '12. Contact',
        paragraphs: ['Questions about these terms: ${tenant.supportEmail}.'],
      ),
    ];

/// Privacy Policy content for [tenant] — see [termsAndConditionsSections].
List<LegalSection> privacyPolicySections([TenantConfig tenant = currentTenant]) => [
      LegalSection(
        heading: 'Overview',
        paragraphs: [
          'This policy explains what data the ${tenant.appName} app collects and '
              'how it\'s used. It applies to both the sales/catalog side of the app and '
              'the admin section.',
        ],
      ),
      const LegalSection(
        heading: 'Account & sign-in data',
        paragraphs: [
          'If you sign in, we collect the email or username you enter, via Firebase '
              'Authentication, solely to authenticate you and allow syncing the '
              'product catalog to your device. We do not see or store your password '
              'ourselves — it\'s handled directly by Firebase Authentication.',
        ],
      ),
      const LegalSection(
        heading: 'Employee profile data (Medical Representatives)',
        paragraphs: [
          'When an administrator creates a Medical Representative account, we '
              'collect and store: first and last name, a profile photo, area/'
              'territory, job designation, and (optionally) a mobile number and/or '
              'personal email address. This data is visible to administrators and is '
              'used to manage field sales staff and their accounts.',
        ],
      ),
      const LegalSection(
        heading: 'Location and app usage data (Medical Representatives)',
        paragraphs: [
          'For Medical Representative accounts, the app records: the date and time '
              'the app is opened and closed, how long each session lasts, and the '
              'device\'s GPS location at the time the app is opened (if location '
              'access is granted). This data is collected for field oversight and '
              'attendance purposes and is visible to administrators in an in-app '
              'dashboard.',
          'This data is recorded on the device and uploaded to our servers the next '
              'time the device syncs with an internet connection — it is not '
              'transmitted continuously or in real time. This tracking does not apply '
              'to the administrator\'s own account.',
          'If location access is denied, the app continues to work normally — usage '
              'time is still recorded, just without a location.',
        ],
      ),
      const LegalSection(
        heading: 'Crash and diagnostic data',
        paragraphs: [
          'We use Firebase Crashlytics to automatically collect crash reports and '
              'basic device information (device model, OS version, and a device '
              'identifier) when the app crashes or encounters an error, so we can find '
              'and fix bugs.',
        ],
      ),
      const LegalSection(
        heading: 'Usage analytics',
        paragraphs: [
          'We use Firebase Analytics to collect basic, aggregated usage data (e.g. '
              'which screens are viewed) to understand how the app is used.',
        ],
      ),
      const LegalSection(
        heading: 'Product catalog data',
        paragraphs: [
          'The app downloads a product catalog (names, descriptions, images) from '
              'our Firebase database and stores it locally on your device so it can '
              'be viewed offline. This data is about our products, not about you.',
        ],
      ),
      const LegalSection(
        heading: 'How we use this data',
        bullets: [
          'To let you sign in and download the current product catalog.',
          'To let administrators manage the catalog and Medical Representative accounts.',
          'To give administrators visibility into field app usage (time and location at open) for oversight purposes.',
          'To diagnose and fix crashes and bugs.',
          'To understand overall app usage and improve the app.',
        ],
      ),
      const LegalSection(
        heading: 'Who can see this data',
        paragraphs: [
          'Employee profile data and location/usage data are visible only to '
              'administrators, within the app\'s admin section. We do not sell your '
              'data. We do not share it with third parties other than our service '
              'providers (Google Firebase, which processes data strictly on our '
              'behalf to provide the services described above).',
        ],
      ),
      LegalSection(
        heading: 'Data retention and deletion',
        paragraphs: [
          'Catalog data cached on your device can be cleared by uninstalling the '
              'app. Employee accounts and their associated data are removed when an '
              'administrator removes that employee from the app. To request deletion '
              'of your own data, contact us at ${tenant.supportEmail}.',
        ],
      ),
      const LegalSection(
        heading: 'Children\'s privacy',
        paragraphs: [
          'This app is intended for business use by sales personnel and administrators '
              'and is not directed at children.',
        ],
      ),
      const LegalSection(
        heading: 'Changes to this policy',
        paragraphs: [
          'We may update this policy from time to time. Continued use of the app '
              'after changes means you accept the updated policy.',
        ],
      ),
      LegalSection(
        heading: 'Contact',
        paragraphs: ['Questions about this policy: ${tenant.supportEmail}.'],
      ),
    ];
