import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/admin_profile.dart';
import '../../domain/models/employee.dart';
import '../auth/auth_controller.dart';

/// The signed-in MR's own profile, live-updated. Only meaningful when the
/// signed-in user isn't the admin (see `isAdminProvider` in
/// `features/admin/admin_access.dart`) — the admin has no `Users` doc at
/// all, so this just never emits for them.
final myEmployeeProfileProvider = StreamProvider<Employee?>((ref) {
  final uid = ref.watch(authControllerProvider).value?.uid;
  debugPrint('myEmployeeProfileProvider: uid=$uid');
  if (uid == null) return const Stream<Employee?>.empty();
  return ref.watch(employeeRepositoryProvider).watchMine(uid);
});

/// The signed-in admin's own profile, live-updated. Only meaningful for the
/// admin account.
final myAdminProfileProvider = StreamProvider<AdminProfile?>((ref) {
  final uid = ref.watch(authControllerProvider).value?.uid;
  debugPrint('myAdminProfileProvider: uid=$uid');
  if (uid == null) return const Stream<AdminProfile?>.empty();
  return ref.watch(adminProfileRepositoryProvider).watch(uid);
});
