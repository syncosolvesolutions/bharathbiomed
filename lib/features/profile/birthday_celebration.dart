import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/tenant/tenant_config.dart';
import '../../domain/models/employee.dart';

/// Shows a one-time "Happy Birthday" celebration for [employee] if today is
/// their birthday and this device hasn't already shown it this year (see the
/// shared_preferences flag below). Safe to call on every app open — a no-op
/// for the rest of the day/year once it's shown.
Future<void> maybeShowBirthdayCelebration(BuildContext context, Employee employee) async {
  if (!employee.isBirthdayToday) return;
  final prefs = await SharedPreferences.getInstance();
  final key = 'birthday_shown_${employee.uid}_${DateTime.now().year}';
  debugPrint('maybeShowBirthdayCelebration: checking flag key=$key');
  if (prefs.getBool(key) == true) {
    debugPrint('maybeShowBirthdayCelebration: already shown this year, skipping');
    return;
  }
  await prefs.setBool(key, true);
  debugPrint('maybeShowBirthdayCelebration: showing celebration for uid=${employee.uid}');
  if (!context.mounted) return;
  await showBirthdayCelebration(context, employee);
}

/// Shows the celebration dialog unconditionally — used both by
/// [maybeShowBirthdayCelebration] and by the cake icon in the catalog app
/// bar, which lets an MR re-open it later in the day after dismissing it.
Future<void> showBirthdayCelebration(BuildContext context, Employee employee) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Happy Birthday',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 500),
    pageBuilder: (context, _, __) => _BirthdayDialog(name: employee.firstName),
    transitionBuilder: (context, animation, _, child) {
      final scale = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.elasticOut),
      );
      final opacity = CurvedAnimation(parent: animation, curve: Curves.easeIn);
      return Opacity(
        opacity: opacity.value,
        child: Transform.scale(scale: scale.value, child: child),
      );
    },
  );
}

class _BirthdayDialog extends StatelessWidget {
  const _BirthdayDialog({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primary, const Color(0xFF7C4DFF)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉 🎈 🎂 🎈 🎉', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 16),
            Text(
              'Happy Birthday,\n$name!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Wishing you a wonderful year ahead — from all of us at ${currentTenant.appName}.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
              ),
              child: const Text('Thank You!'),
            ),
          ],
        ),
      ),
    );
  }
}
