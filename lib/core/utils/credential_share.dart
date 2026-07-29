import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../tenant/tenant_config.dart';

/// Builds the "your account is ready" message handed to a new/edited MR.
/// Omits the password line when [password] is null/empty — that's the case
/// when editing an existing account, where the admin doesn't know the
/// current password (see employee_form_screen.dart's `_isEditing` branch;
/// only account creation and "Reset Password" ever know a plaintext
/// password to include here).
String buildCredentialsMessage({
  required String name,
  required String username,
  required String loginEmail,
  String? password,
}) {
  final passwordLine = (password == null || password.isEmpty) ? '' : '\nPassword: $password';
  return 'Hi $name, your ${currentTenant.appName} account has been created successfully. '
      'Please login with:\nUsername: $username\nEmail: $loginEmail$passwordLine\n\n'
      '– ${currentTenant.appName}';
}

/// Strips everything but digits, then assumes the active tenant's
/// [TenantConfig.defaultCountryCode] if no country code looks present
/// already — this app's MR mobile numbers are entered as plain 10-digit
/// numbers (see the `maxLength: 10` field in employee_form_screen.dart).
/// This is an assumption, not a stored per-number preference.
String toWhatsAppNumber(String mobileNumber) {
  final digits = mobileNumber.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length > 10) return digits; // already looks like it has a country code
  return '${currentTenant.defaultCountryCode}$digits';
}

/// Opens WhatsApp with [message] prefilled for [mobileNumber], via the
/// universal `wa.me` link (works whether or not WhatsApp is installed on
/// this device, unlike the `whatsapp://send` scheme). Returns whether the
/// launch succeeded, so the caller can show an error if WhatsApp isn't
/// reachable.
Future<bool> launchWhatsApp({required String mobileNumber, required String message}) async {
  final number = toWhatsAppNumber(mobileNumber);
  final uri = Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(message)}');
  debugPrint('launchWhatsApp: launching $uri');
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  debugPrint('launchWhatsApp: launched=$launched');
  return launched;
}

/// Generic OS share sheet — lets the admin pick any app (SMS, email, etc.)
/// as a fallback/alternative to WhatsApp.
Future<void> shareCredentials(String message) async {
  debugPrint('shareCredentials: opening share sheet');
  await SharePlus.instance.share(ShareParams(text: message, subject: '${currentTenant.appName} – Login Details'));
  debugPrint('shareCredentials: share sheet closed');
}
