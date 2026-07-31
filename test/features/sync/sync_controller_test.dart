import 'dart:async';

import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:bharathbiomedpharma/data/repositories/agency_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/compliance_log_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/doctor_change_request_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/doctor_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/doctor_visit_log_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/doctor_visit_plan_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/entity_change_request_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/expense_claim_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/order_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/pharmacy_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/product_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/rcpa_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/usage_session_repository.dart';
import 'package:bharathbiomedpharma/features/admin/admin_access.dart';
import 'package:bharathbiomedpharma/features/auth/auth_controller.dart';
import 'package:bharathbiomedpharma/features/catalog/catalog_controller.dart';
import 'package:bharathbiomedpharma/features/sync/sync_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/harness.dart';

class MockProductRepository extends Mock implements ProductRepository {}

class MockDoctorRepository extends Mock implements DoctorRepository {}

class MockAgencyRepository extends Mock implements AgencyRepository {}

class MockPharmacyRepository extends Mock implements PharmacyRepository {}

class MockUsageSessionRepository extends Mock implements UsageSessionRepository {}

class MockDoctorChangeRequestRepository extends Mock implements DoctorChangeRequestRepository {}

class MockDoctorVisitLogRepository extends Mock implements DoctorVisitLogRepository {}

class MockEntityChangeRequestRepository extends Mock implements EntityChangeRequestRepository {}

class MockOrderRepository extends Mock implements OrderRepository {}

class MockRcpaRepository extends Mock implements RcpaRepository {}

class MockExpenseClaimRepository extends Mock implements ExpenseClaimRepository {}

class MockComplianceLogRepository extends Mock implements ComplianceLogRepository {}

class MockDoctorVisitPlanRepository extends Mock implements DoctorVisitPlanRepository {}

class MockUser extends Mock implements User {}

/// Stands in for [AuthController] so [SyncController] sees a fixed signed-in
/// (or signed-out) user without wiring up a real `AuthRepository`/Firebase
/// auth-state stream.
class _StubAuthController extends AuthController {
  _StubAuthController(this._user);
  final User? _user;

  @override
  Future<User?> build() async => _user;
}

/// Stands in for [CatalogController] so [SyncController.startSync] can be
/// driven against a controlled `sync()`. A plain mock can't be dropped into
/// an `AsyncNotifierProvider.overrideWith`, and exercising the real
/// `CatalogController.sync()` would mean stubbing a dozen unrelated
/// repositories and controllers it also touches — this isolates
/// `SyncController`'s own progress/availability bookkeeping instead.
class _StubCatalogController extends CatalogController {
  _StubCatalogController(this._sync);
  final Future<void> Function({SyncProgressCallback? onProgress}) _sync;

  @override
  Future<CatalogSnapshot> build() async => const CatalogSnapshot(products: [], departments: []);

  @override
  Future<void> sync({SyncProgressCallback? onProgress}) => _sync(onProgress: onProgress);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockProductRepository products;
  late MockDoctorRepository doctors;
  late MockAgencyRepository agencies;
  late MockPharmacyRepository pharmacies;
  late MockUsageSessionRepository usageSessions;
  late MockDoctorChangeRequestRepository doctorChangeRequests;
  late MockDoctorVisitLogRepository doctorVisitLogs;
  late MockEntityChangeRequestRepository entityChangeRequests;
  late MockOrderRepository orders;
  late MockRcpaRepository rcpa;
  late MockExpenseClaimRepository expenseClaims;
  late MockComplianceLogRepository complianceLogs;
  late MockDoctorVisitPlanRepository doctorVisitPlans;

  MockUser buildUser(String uid) {
    final user = MockUser();
    when(() => user.uid).thenReturn(uid);
    when(() => user.email).thenReturn('$uid@example.com');
    return user;
  }

  /// Wires every repository [SyncController.checkForUpdates] touches (all
  /// defaulted to "nothing pending" in `setUp` below) plus a stubbed
  /// [AuthController] and [isAdminProvider], and waits for the stub auth
  /// state to resolve — mirroring the real `build()` being asynchronous —
  /// so a test doesn't race `checkForUpdates`' `AsyncLoading` window.
  Future<ProviderContainer> buildContainer({User? user, bool isAdmin = false, List<Override> extra = const []}) async {
    final container = ProviderContainer(overrides: [
      productRepositoryProvider.overrideWithValue(products),
      doctorRepositoryProvider.overrideWithValue(doctors),
      agencyRepositoryProvider.overrideWithValue(agencies),
      pharmacyRepositoryProvider.overrideWithValue(pharmacies),
      usageSessionRepositoryProvider.overrideWithValue(usageSessions),
      doctorChangeRequestRepositoryProvider.overrideWithValue(doctorChangeRequests),
      doctorVisitLogRepositoryProvider.overrideWithValue(doctorVisitLogs),
      entityChangeRequestRepositoryProvider.overrideWithValue(entityChangeRequests),
      orderRepositoryProvider.overrideWithValue(orders),
      rcpaRepositoryProvider.overrideWithValue(rcpa),
      expenseClaimRepositoryProvider.overrideWithValue(expenseClaims),
      complianceLogRepositoryProvider.overrideWithValue(complianceLogs),
      doctorVisitPlanRepositoryProvider.overrideWithValue(doctorVisitPlans),
      authControllerProvider.overrideWith(() => _StubAuthController(user)),
      isAdminProvider.overrideWithValue(isAdmin),
      ...extra,
    ]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    return container;
  }

  setUpAll(() async {
    // SyncController's catch blocks unconditionally call AppLogger.error,
    // which reaches FirebaseCrashlytics.instance — needs faking even though
    // this suite never touches Firebase directly.
    await ensureFirebaseFaked();
  });

  setUp(() {
    products = MockProductRepository();
    doctors = MockDoctorRepository();
    agencies = MockAgencyRepository();
    pharmacies = MockPharmacyRepository();
    usageSessions = MockUsageSessionRepository();
    doctorChangeRequests = MockDoctorChangeRequestRepository();
    doctorVisitLogs = MockDoctorVisitLogRepository();
    entityChangeRequests = MockEntityChangeRequestRepository();
    orders = MockOrderRepository();
    rcpa = MockRcpaRepository();
    expenseClaims = MockExpenseClaimRepository();
    complianceLogs = MockComplianceLogRepository();
    doctorVisitPlans = MockDoctorVisitPlanRepository();

    when(() => products.hasRemoteChanges()).thenAnswer((_) async => false);
    when(() => doctors.hasRemoteChanges(mrUid: any(named: 'mrUid'))).thenAnswer((_) async => false);
    when(() => agencies.hasRemoteChanges()).thenAnswer((_) async => false);
    when(() => pharmacies.hasRemoteChanges()).thenAnswer((_) async => false);
    when(() => usageSessions.countPendingUpload()).thenAnswer((_) async => 0);
    when(() => doctorChangeRequests.countPendingUpload()).thenAnswer((_) async => 0);
    when(() => doctorVisitLogs.countPendingUpload()).thenAnswer((_) async => 0);
    when(() => entityChangeRequests.countPendingUpload()).thenAnswer((_) async => 0);
    when(() => orders.countPendingUpload()).thenAnswer((_) async => 0);
    when(() => rcpa.countPendingUpload()).thenAnswer((_) async => 0);
    when(() => expenseClaims.countPendingUpload()).thenAnswer((_) async => 0);
    when(() => complianceLogs.countPendingUpload()).thenAnswer((_) async => 0);
    when(() => doctorVisitPlans.hasPendingUpload(any())).thenAnswer((_) async => false);
  });

  group('checkForUpdates', () {
    test('does nothing when no user is signed in', () async {
      final container = await buildContainer(user: null);

      await container.read(syncControllerProvider.notifier).checkForUpdates();

      expect(container.read(syncControllerProvider).availability, SyncAvailability.none);
      verifyNever(() => products.hasRemoteChanges());
    });

    test('aggregates remote changes and every pending-upload queue for a signed-in MR', () async {
      when(() => products.hasRemoteChanges()).thenAnswer((_) async => true);
      when(() => usageSessions.countPendingUpload()).thenAnswer((_) async => 2);
      when(() => doctorVisitLogs.countPendingUpload()).thenAnswer((_) async => 1);
      when(() => doctorVisitPlans.hasPendingUpload('mr1')).thenAnswer((_) async => true);
      final container = await buildContainer(user: buildUser('mr1'));

      await container.read(syncControllerProvider.notifier).checkForUpdates();

      final availability = container.read(syncControllerProvider).availability;
      expect(availability.remoteHasUpdates, isTrue);
      expect(availability.pendingUploadCount, 4);
      expect(availability.hasSomethingToSync, isTrue);
      verify(() => doctors.hasRemoteChanges(mrUid: 'mr1')).called(1);
      verify(() => doctorVisitPlans.hasPendingUpload('mr1')).called(1);
    });

    test('an admin is checked with mrUid=null and never touches the visit-plan queue', () async {
      final container = await buildContainer(user: buildUser('admin1'), isAdmin: true);

      await container.read(syncControllerProvider.notifier).checkForUpdates();

      verify(() => doctors.hasRemoteChanges(mrUid: null)).called(1);
      verifyNever(() => doctorVisitPlans.hasPendingUpload(any()));
    });

    test('reports nothing to sync when every source is clean', () async {
      final container = await buildContainer(user: buildUser('mr1'));

      await container.read(syncControllerProvider.notifier).checkForUpdates();

      expect(container.read(syncControllerProvider).availability.hasSomethingToSync, isFalse);
    });

    test('a failed check leaves a previously-known availability exactly as it was', () async {
      when(() => usageSessions.countPendingUpload()).thenAnswer((_) async => 3);
      final container = await buildContainer(user: buildUser('mr1'));
      await container.read(syncControllerProvider.notifier).checkForUpdates();
      expect(container.read(syncControllerProvider).availability.pendingUploadCount, 3);

      when(() => products.hasRemoteChanges()).thenThrow(Exception('offline'));

      await container.read(syncControllerProvider.notifier).checkForUpdates();

      expect(container.read(syncControllerProvider).availability.pendingUploadCount, 3);
    });
  });

  group('startSync', () {
    test('reports step progress while running, then clears availability and progress on success', () async {
      final progressLabels = <String>[];
      final container = await buildContainer(user: buildUser('mr1'), extra: [
        catalogControllerProvider.overrideWith(() => _StubCatalogController(({onProgress}) async {
              onProgress?.call(0, 2, 'Downloading catalog…');
              onProgress?.call(2, 2, 'Sync complete');
            })),
      ]);
      container.listen(syncControllerProvider, (previous, next) {
        if (next.progress != null) progressLabels.add(next.progress!.label);
      });

      await container.read(syncControllerProvider.notifier).startSync();

      expect(progressLabels, ['Starting sync…', 'Downloading catalog…', 'Sync complete']);
      expect(container.read(syncControllerProvider), const SyncState());
    });

    test('a second call while a sync is already running is a no-op', () async {
      final syncStarted = Completer<void>();
      final releaseSync = Completer<void>();
      var syncCallCount = 0;
      final container = await buildContainer(user: buildUser('mr1'), extra: [
        catalogControllerProvider.overrideWith(() => _StubCatalogController(({onProgress}) async {
              syncCallCount++;
              syncStarted.complete();
              await releaseSync.future;
            })),
      ]);

      final first = container.read(syncControllerProvider.notifier).startSync();
      await syncStarted.future;
      await container.read(syncControllerProvider.notifier).startSync();
      releaseSync.complete();
      await first;

      expect(syncCallCount, 1);
    });

    test('keeps the previously-known availability, clears progress, and rethrows on failure', () async {
      when(() => usageSessions.countPendingUpload()).thenAnswer((_) async => 5);
      final container = await buildContainer(user: buildUser('mr1'), extra: [
        catalogControllerProvider.overrideWith(() => _StubCatalogController(({onProgress}) async {
              throw Exception('sync failed');
            })),
      ]);
      await container.read(syncControllerProvider.notifier).checkForUpdates();
      expect(container.read(syncControllerProvider).availability.pendingUploadCount, 5);

      await expectLater(container.read(syncControllerProvider.notifier).startSync(), throwsException);

      final state = container.read(syncControllerProvider);
      expect(state.availability.pendingUploadCount, 5);
      expect(state.progress, isNull);
    });
  });
}
