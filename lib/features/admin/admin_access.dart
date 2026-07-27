import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/admin_access.dart';
import '../auth/auth_controller.dart';

/// Whether the currently signed-in user should see the Admin section.
final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(authControllerProvider).value;
  return isAdminEmail(user?.email);
});
