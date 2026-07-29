import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/admin_notifications_repository.dart';
import 'repositories/admin_profile_repository.dart';
import 'repositories/agency_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/compliance_log_repository.dart';
import 'repositories/designation_repository.dart';
import 'repositories/device_token_repository.dart';
import 'repositories/doctor_change_request_repository.dart';
import 'repositories/doctor_repository.dart';
import 'repositories/doctor_visit_log_repository.dart';
import 'repositories/doctor_visit_plan_repository.dart';
import 'repositories/employee_repository.dart';
import 'repositories/entity_change_request_repository.dart';
import 'repositories/expense_claim_repository.dart';
import 'repositories/invoice_repository.dart';
import 'repositories/leave_request_repository.dart';
import 'repositories/order_repository.dart';
import 'repositories/pharmacy_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/rcpa_repository.dart';
import 'repositories/reminder_repository.dart';
import 'repositories/sales_target_repository.dart';
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

final doctorRepositoryProvider = Provider<DoctorRepository>((ref) => DoctorRepository());

final doctorChangeRequestRepositoryProvider =
    Provider<DoctorChangeRequestRepository>((ref) => DoctorChangeRequestRepository());

final doctorVisitPlanRepositoryProvider =
    Provider<DoctorVisitPlanRepository>((ref) => DoctorVisitPlanRepository());

final doctorVisitLogRepositoryProvider =
    Provider<DoctorVisitLogRepository>((ref) => DoctorVisitLogRepository());

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) => ReminderRepository());

final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>((ref) => DeviceTokenRepository());

final agencyRepositoryProvider = Provider<AgencyRepository>((ref) => AgencyRepository());

final pharmacyRepositoryProvider = Provider<PharmacyRepository>((ref) => PharmacyRepository());

final entityChangeRequestRepositoryProvider =
    Provider<EntityChangeRequestRepository>((ref) => EntityChangeRequestRepository());

final orderRepositoryProvider = Provider<OrderRepository>((ref) => OrderRepository());

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) => InvoiceRepository());

final salesTargetRepositoryProvider = Provider<SalesTargetRepository>((ref) => SalesTargetRepository());

final rcpaRepositoryProvider = Provider<RcpaRepository>((ref) => RcpaRepository());

final expenseClaimRepositoryProvider = Provider<ExpenseClaimRepository>((ref) => ExpenseClaimRepository());

final leaveRequestRepositoryProvider = Provider<LeaveRequestRepository>((ref) => LeaveRequestRepository());

final complianceLogRepositoryProvider = Provider<ComplianceLogRepository>((ref) => ComplianceLogRepository());
