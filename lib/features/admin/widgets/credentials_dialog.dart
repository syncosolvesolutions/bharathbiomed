import 'package:flutter/material.dart';

import '../../../core/utils/credential_share.dart';

/// The post-save "here are this MR's login details" dialog, with WhatsApp
/// and generic-share actions alongside the plain "Done" — shown after
/// creating/editing an employee (employee_form_screen.dart) and after
/// resetting a password (manage_employees_screen.dart). The WhatsApp button
/// is disabled (with an explanatory tooltip) when there's no mobile number
/// on file, since [launchWhatsApp] needs one to build the `wa.me` link.
Future<void> showCredentialsDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? mobileNumber,
}) {
  final hasMobile = mobileNumber != null && mobileNumber.isNotEmpty;
  debugPrint('showCredentialsDialog: title=$title hasMobile=$hasMobile');

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(message)),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        Tooltip(
          message: hasMobile ? 'Send via WhatsApp' : 'Add a mobile number to enable WhatsApp',
          child: TextButton.icon(
            onPressed: !hasMobile
                ? null
                : () async {
                    debugPrint('showCredentialsDialog: WhatsApp button pressed');
                    final launched = await launchWhatsApp(mobileNumber: mobileNumber, message: message);
                    if (!context.mounted) return;
                    if (!launched) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
                    }
                  },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('WhatsApp'),
          ),
        ),
        TextButton.icon(
          onPressed: () {
            debugPrint('showCredentialsDialog: Share button pressed');
            shareCredentials(message);
          },
          icon: const Icon(Icons.share_outlined),
          label: const Text('Share'),
        ),
        TextButton(
          onPressed: () {
            debugPrint('showCredentialsDialog: Done button pressed');
            Navigator.of(context).pop();
          },
          child: const Text('Done'),
        ),
      ],
    ),
  );
}
