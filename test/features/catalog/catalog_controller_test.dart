import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:bharathbiomedpharma/data/repositories/compliance_log_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/doctor_change_request_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/doctor_visit_log_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/doctor_visit_plan_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/entity_change_request_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/expense_claim_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/order_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/product_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/rcpa_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/usage_session_repository.dart';
import 'package:bharathbiomedpharma/domain/models/agency.dart';
import 'package:bharathbiomedpharma/domain/models/doctor.dart';
import 'package:bharathbiomedpharma/domain/models/pharmacy.dart';
import 'package:bharathbiomedpharma/domain/models/product.dart';
import 'package:bharathbiomedpharma/features/admin/admin_access.dart';
import 'package:bharathbiomedpharma/features/agencies/agency_controller.dart';
import 'package:bharathbiomedpharma/features/auth/auth_controller.dart';
import 'package:bharathbiomedpharma/features/catalog/catalog_controller.dart';
import 'package:bharathbiomedpharma/features/doctors/doctor_controller.dart';
import 'package:bharathbiomedpharma/features/pharmacies/pharmacy_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProductRepository extends Mock implements ProductRepository {}

class MockUsageSessionRepository extends Mock implements UsageSessionRepository {}

class MockDoctorChangeRequestRepository extends Mock implements DoctorChangeRequestRepository {}

class MockDoctorVisitLogRepository extends Mock implements DoctorVisitLogRepository {}

class MockDoctorVisitPlanRepository extends Mock implements DoctorVisitPlanRepository {}

class MockEntityChangeRequestRepository extends Mock implements EntityChangeRequestRepository {}

class MockOrderRepository extends Mock implements OrderRepository {}

class MockRcpaRepository extends Mock implements RcpaRepository {}

class MockExpenseClaimRepository extends Mock implements ExpenseClaimRepository {}

class MockComplianceLogRepository extends Mock implements ComplianceLogRepository {}

class MockUser extends Mock implements User {}

class _StubAuthController extends AuthController {
  _StubAuthController(this._user);
  final User? _user;
  @override
  Future<User?> build() async => _user;
}

class _StubDoctorController extends DoctorController {
  _StubDoctorController(this._sync);
  final Future<void> Function() _sync;
  @override
  Future<List<Doctor>> build() async => const [];
  @override
  Future<void> sync() => _sync();
}

class _StubAgencyController extends AgencyController {
  _StubAgencyController(this._sync);
  final Future<void> Function() _sync;
  @override
  Future<List<Agency>> build() async => const [];
  @override
  Future<void> sync() => _sync();
}

class _StubPharmacyController extends PharmacyController {
  _StubPharmacyController(this._sync);
  final Future<void> Function() _sync;
  @override
  Future<List<Pharmacy>> build() async => const [];
  @override
  Future<void> sync() => _sync();
}

void main() {
  late MockProductRepository products;
  late MockUsageSessionRepository usageSessions;
  late MockDoctorChangeRequestRepository doctorChangeRequests;
  late MockDoctorVisitLogRepository doctorVisitLogs;
  late MockDoctorVisitPlanRepository doctorVisitPlans;
  late MockEntityChangeRequestRepository entityChangeRequests;
  late MockOrderRepository orders;
  late MockRcpaRepository rcpa;
  late MockExpenseClaimRepository expenseClaims;
  late MockComplianceLogRepository complianceLogs;

  const emptySnapshot = CatalogSnapshot(products: [], departments: []);
  const syncedSnapshot = CatalogSnapshot(
    products: [Product(id: 'p1', name: 'Paracetamol', info: 'Pain relief', departments: {'General': 0}, imageUrl: '')],
    departments: ['General'],
  );

  Future<ProviderContainer> buildContainer({
    User? user,
    bool isAdmin = false,
    Future<void> Function() doctorSync = _noop,
    Future<void> Function() agencySync = _noop,
    Future<void> Function() pharmacySync = _noop,
  }) async {
    final container = ProviderContainer(overrides: [
      productRepositoryProvider.overrideWithValue(products),
      usageSessionRepositoryProvider.overrideWithValue(usageSessions),
      doctorChangeRequestRepositoryProvider.overrideWithValue(doctorChangeRequests),
      doctorVisitLogRepositoryProvider.overrideWithValue(doctorVisitLogs),
      doctorVisitPlanRepositoryProvider.overrideWithValue(doctorVisitPlans),
      entityChangeRequestRepositoryProvider.overrideWithValue(entityChangeRequests),
      orderRepositoryProvider.overrideWithValue(orders),
      rcpaRepositoryProvider.overrideWithValue(rcpa),
      expenseClaimRepositoryProvider.overrideWithValue(expenseClaims),
      complianceLogRepositoryProvider.overrideWithValue(complianceLogs),
      authControllerProvider.overrideWith(() => _StubAuthController(user)),
      isAdminProvider.overrideWithValue(isAdmin),
      doctorControllerProvider.overrideWith(() => _StubDoctorController(doctorSync)),
      agencyControllerProvider.overrideWith(() => _StubAgencyController(agencySync)),
      pharmacyControllerProvider.overrideWith(() => _StubPharmacyController(pharmacySync)),
    ]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    // Resolve CatalogController's own build() (reads the cached snapshot)
    // before the test drives sync() — otherwise reading `.value` on a
    // still-AsyncLoading state races the assertions below.
    await container.read(catalogControllerProvider.future);
    return container;
  }

  setUp(() {
    products = MockProductRepository();
    usageSessions = MockUsageSessionRepository();
    doctorChangeRequests = MockDoctorChangeRequestRepository();
    doctorVisitLogs = MockDoctorVisitLogRepository();
    doctorVisitPlans = MockDoctorVisitPlanRepository();
    entityChangeRequests = MockEntityChangeRequestRepository();
    orders = MockOrderRepository();
    rcpa = MockRcpaRepository();
    expenseClaims = MockExpenseClaimRepository();
    complianceLogs = MockComplianceLogRepository();

    when(() => products.loadCachedCatalog()).thenAnswer((_) async => emptySnapshot);
    when(() => products.sync()).thenAnswer((_) async => syncedSnapshot);
    when(() => usageSessions.uploadPending()).thenAnswer((_) async {});
    when(() => doctorChangeRequests.uploadPending()).thenAnswer((_) async {});
    when(() => doctorVisitLogs.uploadPending()).thenAnswer((_) async {});
    when(() => doctorVisitPlans.pushUnsynced(any())).thenAnswer((_) async {});
    when(() => entityChangeRequests.uploadPending()).thenAnswer((_) async {});
    when(() => orders.uploadPending()).thenAnswer((_) async {});
    when(() => rcpa.uploadPending()).thenAnswer((_) async {});
    when(() => expenseClaims.uploadPending()).thenAnswer((_) async {});
    when(() => complianceLogs.uploadPending()).thenAnswer((_) async {});
  });

  test('runs every step and reports progress from 0 through "Sync complete"', () async {
    final container = await buildContainer(user: buildUser());
    final steps = <String>[];

    await container.read(catalogControllerProvider.notifier).sync(
          onProgress: (completed, total, label) => steps.add('$completed/$total $label'),
        );

    expect(steps.first, '0/13 Downloading catalog…');
    expect(steps.last, '13/13 Sync complete');
    expect(steps, hasLength(14)); // 13 per-step reports + the final "Sync complete" call.
    expect(container.read(catalogControllerProvider).value, syncedSnapshot);
  });

  test('the catalog-download step is NOT best-effort: its failure is not caught, and no later step runs', () async {
    final container = await buildContainer(user: buildUser());
    when(() => products.sync()).thenThrow(Exception('offline'));

    await expectLater(
      container.read(catalogControllerProvider.notifier).sync(),
      throwsException,
    );

    verifyNever(() => usageSessions.uploadPending());
    // build()'s cached snapshot, untouched — the failed sync must not clobber it.
    expect(container.read(catalogControllerProvider).value, emptySnapshot);
  });

  test('one upload step throwing does not block any of the others from running', () async {
    final container = await buildContainer(user: buildUser());
    when(() => usageSessions.uploadPending()).thenThrow(Exception('upload failed'));

    await container.read(catalogControllerProvider.notifier).sync();

    verify(() => doctorChangeRequests.uploadPending()).called(1);
    verify(() => doctorVisitLogs.uploadPending()).called(1);
    verify(() => entityChangeRequests.uploadPending()).called(1);
    verify(() => orders.uploadPending()).called(1);
    verify(() => rcpa.uploadPending()).called(1);
    verify(() => expenseClaims.uploadPending()).called(1);
    verify(() => complianceLogs.uploadPending()).called(1);
    // The catalog itself still ends up updated despite a later step failing.
    expect(container.read(catalogControllerProvider).value, syncedSnapshot);
  });

  test('a failing doctor/agency sync does not block the pharmacy sync or later upload steps', () async {
    var pharmacySynced = false;
    final container = await buildContainer(
      user: buildUser(),
      doctorSync: () async => throw Exception('doctor sync failed'),
      agencySync: () async => throw Exception('agency sync failed'),
      pharmacySync: () async => pharmacySynced = true,
    );

    await container.read(catalogControllerProvider.notifier).sync();

    expect(pharmacySynced, isTrue);
    verify(() => orders.uploadPending()).called(1);
  });

  test('an admin never pushes an unsynced visit plan (mrUid is null)', () async {
    final container = await buildContainer(user: buildUser(uid: 'admin1'), isAdmin: true);

    await container.read(catalogControllerProvider.notifier).sync();

    verifyNever(() => doctorVisitPlans.pushUnsynced(any()));
  });

  test('a signed-in MR pushes their unsynced visit plan, and its failure does not block later steps', () async {
    final container = await buildContainer(user: buildUser(uid: 'mr1'), isAdmin: false);
    when(() => doctorVisitPlans.pushUnsynced('mr1')).thenThrow(Exception('visit plan push failed'));

    await container.read(catalogControllerProvider.notifier).sync();

    verify(() => doctorVisitPlans.pushUnsynced('mr1')).called(1);
    verify(() => entityChangeRequests.uploadPending()).called(1);
    expect(container.read(catalogControllerProvider).value, syncedSnapshot);
  });
}

Future<void> _noop() async {}

MockUser buildUser({String uid = 'mr1'}) {
  final user = MockUser();
  when(() => user.uid).thenReturn(uid);
  when(() => user.email).thenReturn('$uid@example.com');
  return user;
}
