import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/admin_notifications_repository.dart';
import 'repositories/admin_profile_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/designation_repository.dart';
import 'repositories/employee_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/usage_session_repository.dart';

/// Dependency-injection root for the data layer. Features read repositories
/// through these providers rather than constructing them directly, so tests
/// can override them with fakes/mocks.
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final productRepositoryProvider = Provider<ProductRepository>((ref) => ProductRepository());

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) => EmployeeRepository());

final designationRepositoryProvider = Provider<DesignationRepository>((ref) => DesignationRepository());

final usageSessionRepositoryProvider = Provider<UsageSessionRepository>((ref) => UsageSessionRepository());

final adminProfileRepositoryProvider = Provider<AdminProfileRepository>((ref) => AdminProfileRepository());

final adminNotificationsRepositoryProvider =
    Provider<AdminNotificationsRepository>((ref) => AdminNotificationsRepository());
