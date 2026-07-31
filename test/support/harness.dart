import 'dart:async';
import 'dart:io';

import 'package:bharathbiomedpharma/core/connectivity/connectivity_provider.dart';
import 'package:bharathbiomedpharma/core/router/app_router.dart';
import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_crashlytics_platform_interface/firebase_crashlytics_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// `LocationService.getCurrentLocationBestEffort` (called unconditionally by
/// the visit-log dialog, the doctor form, and the RCPA form's "Use Current
/// Location") never throws by design — but that guarantee rests on
/// `GeolocatorPlatform.instance` actually responding. Left at its real
/// default in a plain `flutter test` run, its platform-channel call to
/// `checkPermission()` never gets a reply at all (same class of problem as
/// the Firebase channels above) and just hangs forever instead of
/// rejecting, taking `settle`'s budget down with it. Denied permission is
/// the simplest response that satisfies every Phase 1 flow: none of them
/// assert on a real GPS fix, only that the surrounding save/submit flow
/// completes. Mirrors `test/features/tracking/location_service_test.dart`'s
/// own mock, which faces the identical gap for its unit tests.
class _MockGeolocatorPlatform extends Mock with MockPlatformInterfaceMixin implements GeolocatorPlatform {}

void _fakeGeolocator() {
  final platform = _MockGeolocatorPlatform();
  when(() => platform.checkPermission()).thenAnswer((_) async => LocationPermission.denied);
  when(() => platform.requestPermission()).thenAnswer((_) async => LocationPermission.denied);
  GeolocatorPlatform.instance = platform;
}

/// `ProductCard` renders every product photo through `CachedNetworkImage`,
/// which — for any URL, even a deliberately empty test fixture one — tries a
/// real `HttpClient` request. Nothing answers that request in the sandboxed
/// test network, so it never resolves either way, and its `placeholder`'s
/// indeterminate spinner keeps a frame scheduled forever: `pumpAndSettle`
/// then hangs on the very first screen with a product in it, not because
/// anything is actually broken. Failing every request immediately (instead
/// of leaving it to hang) makes `CachedNetworkImage` fall through to
/// `errorWidget` right away, which is inert.
class _NoNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FailFastHttpClient();
}

class _FailFastHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw const SocketException('Network access is disabled in widget tests.');
}

/// A handful of widgets (`PhotoPickerField`'s `ImageUploader`, in
/// particular) grab `Firebase*.instance` in a field initializer — eagerly,
/// unguarded by any try/catch, the moment their State is constructed, not
/// lazily when a photo is actually picked. None of Phase 1's flows ever tap
/// "Add Photo" (so no real Storage/Firestore/Auth call is ever attempted),
/// but simply *mounting* `DoctorFormScreen`/`CompleteProfileScreen` would
/// otherwise crash with "[core/no-app] No Firebase App '[DEFAULT]' has been
/// created" before the widget tree even finishes building. And any caught
/// error that reaches `AppLogger.error` (most catch blocks in the app) calls
/// `FirebaseCrashlytics.instance`, which asserts on a `pluginConstants` map
/// that's normally populated by the native `Firebase#initializeApp`
/// response — so *that* needs faking too, not just `Firebase.app()` itself.
///
/// `firebase_core` (this version) generates its platform channel via Pigeon
/// rather than the classic string-keyed `MethodChannel` — mocking that
/// directly (the obvious first approach) just makes `Firebase.initializeApp`
/// hang waiting for a reply nothing ever sends, since it's the wrong
/// channel entirely. `package:firebase_core_platform_interface/test.dart`'s
/// `TestFirebaseCoreHostApi.setUp` is the real Pigeon-generated test seam
/// (the same one `firebase_core`'s and `firebase_crashlytics`'s own test
/// suites use) — routing `Firebase.initializeApp()` through the actual
/// `MethodChannelFirebase` implementation with this mocked underneath it,
/// rather than swapping in a hand-rolled `FirebasePlatform`, is what lets
/// `pluginConstants` (crashlytics' collection-enabled flag included) reach
/// `FirebasePlugin`'s internal registry the normal way.
class _FakeFirebaseCoreHostApi implements TestFirebaseCoreHostApi {
  static const _crashlyticsChannel = 'plugins.flutter.io/firebase_crashlytics';

  CoreFirebaseOptions get _options => CoreFirebaseOptions(
        apiKey: 'test-api-key',
        appId: 'test-app-id',
        messagingSenderId: 'test-sender-id',
        projectId: 'test-project-id',
        storageBucket: 'test-project-id.appspot.com',
      );

  CoreInitializeResponse _response(String name) => CoreInitializeResponse(
        name: name,
        options: _options,
        pluginConstants: {
          _crashlyticsChannel: {'isCrashlyticsCollectionEnabled': false},
        },
      );

  @override
  Future<CoreInitializeResponse> initializeApp(String appName, CoreFirebaseOptions initializeAppRequest) async =>
      _response(appName);

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [_response(defaultFirebaseAppName)];

  @override
  Future<CoreFirebaseOptions> optionsFromResource() async => _options;
}

bool _firebaseFaked = false;

/// One-time process-wide setup for the `firebase_core`/`firebase_crashlytics`
/// platform channels — needed by *any* test that reaches `AppLogger.error`
/// (not just full `pumpApp` flow tests), since it unconditionally calls
/// `FirebaseCrashlytics.instance`, which asserts on a `pluginConstants` map
/// normally populated by the native `Firebase#initializeApp` response. See
/// [_ensurePlatformFaked]'s doc comment for why this needs the Pigeon-based
/// `TestFirebaseCoreHostApi` seam rather than a hand-rolled `FirebasePlatform`.
Future<void> ensureFirebaseFaked() async {
  if (_firebaseFaked) return;
  _firebaseFaked = true;
  TestFirebaseCoreHostApi.setUp(_FakeFirebaseCoreHostApi());
  // `AppLogger.error`'s fire-and-forget `FirebaseCrashlytics.instance
  // .recordError(...)` still reaches this classic MethodChannel once past
  // the pluginConstants check above — swallow it the same way
  // firebase_crashlytics's own test suite does.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    MethodChannelFirebaseCrashlytics.channel,
    (call) async => null,
  );

  await Firebase.initializeApp();
}

bool _platformFaked = false;

/// One-time process-wide setup for every platform channel Phase 1's flows
/// touch without going through a Riverpod-injected repository (so none of
/// the fakes in `fakes.dart` can intercept them): [ensureFirebaseFaked]
/// above, plus real network and location.
Future<void> _ensurePlatformFaked() async {
  if (_platformFaked) return;
  _platformFaked = true;
  HttpOverrides.global = _NoNetworkHttpOverrides();
  _fakeGeolocator();
  // The birthday-celebration check (fired on every catalog-screen build)
  // and any reminder/notification "already shown" flags read this — the
  // documented in-memory mock, no platform channel involved.
  SharedPreferences.setMockInitialValues({});

  await ensureFirebaseFaked();
}

/// Bundles one in-memory fake per repository the integration suite touches,
/// wired to each other the way the real repositories are indirectly (e.g.
/// [FakeOrderRepository.dispatch] decrements the very [FakeProductRepository]
/// instance the catalog reads from). Every test builds one of these, seeds
/// whatever fixtures the scenario needs directly on its fields, then pumps
/// the real app via [pumpApp] — the actual screens, navigation, and
/// permission gating run unmodified; only the data layer is swapped out.
///
/// Repositories *not* listed here (agency/pharmacy change requests, usage
/// sessions, reminders, designations, admin profile, device tokens) are
/// deliberately left at their real `data/providers.dart` default rather
/// than faked. Every one of their call sites in the screens exercised so
/// far is wrapped in a try/catch (`CatalogController.sync`'s per-step
/// uploads) — so constructing the real repository and having it fail
/// talking to a non-existent Firebase app is swallowed the same way a real
/// offline failure would be, never a crashed test.
///
/// That courtesy does *not* extend to a provider whose result reaches a
/// screen through `AsyncValue.value` (not `.valueOrNull`) — Riverpod
/// rethrows the underlying error there instead of returning null, so
/// anything read that way needs a real fake regardless of how minor it
/// looks. `adminNotificationsRepositoryProvider` is the one this hits
/// (`unreadAdminNotificationsCountProvider`'s badge count, read on every
/// admin screen); add another the moment a later phase's screen does the
/// same with a still-unfaked repository.
class TestBackend {
  final auth = FakeAuthRepository();
  final employees = FakeEmployeeRepository();
  final products = FakeProductRepository();
  final agencies = FakeAgencyRepository();
  final pharmacies = FakePharmacyRepository();
  final doctors = FakeDoctorRepository();
  late final doctorChangeRequests = FakeDoctorChangeRequestRepository(doctors: doctors);
  final doctorVisitPlans = FakeDoctorVisitPlanRepository();
  final doctorVisitLogs = FakeDoctorVisitLogRepository();
  late final orders = FakeOrderRepository(products: products);
  final salesTargets = FakeSalesTargetRepository();
  final rcpa = FakeRcpaRepository();
  final adminNotifications = FakeAdminNotificationsRepository();
  final expenseClaims = FakeExpenseClaimRepository();
  final complianceLogs = FakeComplianceLogRepository();
  late final entityChangeRequests = FakeEntityChangeRequestRepository(agencies: agencies, pharmacies: pharmacies);
  final designations = FakeDesignationRepository();
  final usageSessions = FakeUsageSessionRepository();
  final reminders = FakeReminderRepository();

  List<Override> get overrides => [
        authRepositoryProvider.overrideWithValue(auth),
        employeeRepositoryProvider.overrideWithValue(employees),
        productRepositoryProvider.overrideWithValue(products),
        agencyRepositoryProvider.overrideWithValue(agencies),
        pharmacyRepositoryProvider.overrideWithValue(pharmacies),
        doctorRepositoryProvider.overrideWithValue(doctors),
        doctorChangeRequestRepositoryProvider.overrideWithValue(doctorChangeRequests),
        doctorVisitPlanRepositoryProvider.overrideWithValue(doctorVisitPlans),
        doctorVisitLogRepositoryProvider.overrideWithValue(doctorVisitLogs),
        orderRepositoryProvider.overrideWithValue(orders),
        salesTargetRepositoryProvider.overrideWithValue(salesTargets),
        rcpaRepositoryProvider.overrideWithValue(rcpa),
        adminNotificationsRepositoryProvider.overrideWithValue(adminNotifications),
        expenseClaimRepositoryProvider.overrideWithValue(expenseClaims),
        complianceLogRepositoryProvider.overrideWithValue(complianceLogs),
        entityChangeRequestRepositoryProvider.overrideWithValue(entityChangeRequests),
        designationRepositoryProvider.overrideWithValue(designations),
        usageSessionRepositoryProvider.overrideWithValue(usageSessions),
        reminderRepositoryProvider.overrideWithValue(reminders),
        // Real `connectivityProvider` reads a platform channel; every
        // Phase 1 scenario runs "online" unless a test overrides this
        // itself for an offline edge case.
        connectivityProvider.overrideWith((ref) => Stream.value(const [ConnectivityResult.wifi])),
      ];
}

/// Root widget for a test run: the real `go_router` config
/// (`routerProvider`), same as `app.dart`'s `BharathBioMedApp`, but without
/// its splash-screen removal, push-notification registration, or app-
/// lifecycle usage-tracking hooks — none of those are relevant to driving a
/// screen in a widget test, and the push-notification/tracking services
/// touch platform channels a plain `flutter test` run doesn't have.
class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(routerConfig: router, debugShowCheckedModeBanner: false);
  }
}

/// Pumps the real app (real screens, real navigation, real permission
/// gating) wired to [backend]'s fakes plus any scenario-specific
/// [extraOverrides]. If [signedInAs] is set, the session is seeded *before*
/// the first frame, so the router's redirect (which reads
/// `authRepositoryProvider.currentUser` synchronously) sends the very first
/// frame straight past `/login` — exactly like a real already-signed-in
/// launch.
Future<void> pumpApp(
  WidgetTester tester, {
  required TestBackend backend,
  User? signedInAs,
  List<Override> extraOverrides = const [],
}) async {
  // The default 800x600 test surface clips several screens' scrollable
  // content (e.g. the login screen's Sign In button sits below the fold),
  // making taps land off-screen. A generously tall viewport avoids that
  // without every test having to know it needs to scroll first.
  tester.view.physicalSize = const Size(1400, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await _ensurePlatformFaked();

  if (signedInAs != null) backend.auth.seedSignedIn(signedInAs);

  // A test that calls `pumpApp` more than once (e.g. "sign in as the MR,
  // then re-launch as their manager") needs each call to be a genuinely
  // fresh app launch — a new router starting at `/login` and redirecting
  // fresh, not wherever the previous session's Navigator happened to leave
  // off. `pumpWidget` only tears down the previous element tree if the new
  // root widget doesn't structurally match it (same type, no key just
  // updates the existing elements in place — including the previous
  // `GoRouter`/`Navigator`'s current location). Pumping an unrelated
  // placeholder first guarantees that teardown before the real tree mounts.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...backend.overrides, ...extraOverrides],
      child: const _TestApp(),
    ),
  );
  await settle(tester);
}

/// A `pumpAndSettle` substitute every test in this suite uses instead of the
/// real thing: any screen with a product photo renders `CachedNetworkImage`,
/// whose `placeholder` is an indeterminate `CircularProgressIndicator` that
/// keeps a frame scheduled for as long as its image resolution never calls
/// back — which, with no real network and no `path_provider` platform
/// channel available in a plain `flutter test` run, is forever, regardless
/// of `HttpOverrides`. `pumpAndSettle` treats "a frame is still scheduled"
/// as "still busy" and hangs on the very first screen with a product on it.
/// Pumping a fixed, generous number of frames instead gets everything real
/// (async fake-repository calls, go_router redirects, finite widget
/// animations/transitions) all the time it needs without ever waiting on
/// that one permanently-scheduled frame.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Dismisses whatever `SnackBar` is currently showing (or queued) instead
/// of waiting out its default 4-second duration — needed between two
/// actions in the same test that each show one (e.g. approve, then
/// dispatch), since `ScaffoldMessenger` only shows one at a time and
/// [settle]'s budget is deliberately short (see its own doc comment).
void clearSnackBars(WidgetTester tester) {
  ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
}

/// The live `go_router` instance behind whatever screen is currently on
/// screen — for tests that need to navigate programmatically (e.g. to a
/// route with no in-app affordance for the signed-in role, exercising a
/// redirect rule directly) or assert on the resolved location.
GoRouter routerOf(WidgetTester tester) => GoRouter.of(tester.element(find.byType(Scaffold).first));
