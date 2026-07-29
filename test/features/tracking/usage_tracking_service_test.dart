import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:bharathbiomedpharma/data/repositories/usage_session_repository.dart';
import 'package:bharathbiomedpharma/features/tracking/usage_tracking_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockUsageSessionRepository extends Mock implements UsageSessionRepository {}

class MockUser extends Mock implements User {}

class MockGeolocatorPlatform extends Mock with MockPlatformInterfaceMixin implements GeolocatorPlatform {}

void main() {
  late MockUsageSessionRepository repository;
  late MockGeolocatorPlatform geolocatorPlatform;
  late GeolocatorPlatform originalPlatform;
  late ProviderContainer container;
  late UsageTrackingService service;

  final position = Position(
    latitude: 12.9,
    longitude: 77.6,
    timestamp: DateTime(2026, 7, 1),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  setUp(() {
    repository = MockUsageSessionRepository();
    container = ProviderContainer(
      overrides: [usageSessionRepositoryProvider.overrideWithValue(repository)],
    );
    service = container.read(usageTrackingServiceProvider);

    geolocatorPlatform = MockGeolocatorPlatform();
    originalPlatform = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = geolocatorPlatform;
    when(() => geolocatorPlatform.checkPermission()).thenAnswer((_) async => LocationPermission.whileInUse);
    when(() => geolocatorPlatform.isLocationServiceEnabled()).thenAnswer((_) async => true);
    when(() => geolocatorPlatform.getCurrentPosition(locationSettings: any(named: 'locationSettings')))
        .thenAnswer((_) async => position);
  });

  tearDown(() {
    container.dispose();
    GeolocatorPlatform.instance = originalPlatform;
  });

  MockUser buildUser({required String uid, String? email, String? displayName}) {
    final user = MockUser();
    when(() => user.uid).thenReturn(uid);
    when(() => user.email).thenReturn(email);
    when(() => user.displayName).thenReturn(displayName);
    return user;
  }

  group('handleAppResumed', () {
    test('starts a session for an MR, with the best-effort location attached', () async {
      final mr = buildUser(uid: 'rep1', email: 'mr-rajesh@bharathbiomed-14368.firebaseapp.com');
      when(() => repository.startSession(
            employeeUid: any(named: 'employeeUid'),
            username: any(named: 'username'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async => 'session1');

      await service.handleAppResumed(mr);

      verify(() => repository.startSession(
            employeeUid: 'rep1',
            username: 'mr-rajesh@bharathbiomed-14368.firebaseapp.com',
            latitude: 12.9,
            longitude: 77.6,
          )).called(1);
    });

    test('never starts a session for the admin account', () async {
      final admin = buildUser(uid: 'admin-uid', email: 'bharathbiomedpharma@gmail.com');

      await service.handleAppResumed(admin);

      verifyNever(() => repository.startSession(
            employeeUid: any(named: 'employeeUid'),
            username: any(named: 'username'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          ));
    });

    test('does nothing when no user is signed in', () async {
      await service.handleAppResumed(null);

      verifyNever(() => repository.startSession(
            employeeUid: any(named: 'employeeUid'),
            username: any(named: 'username'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          ));
    });

    test('falls back to email, then uid, when displayName is unavailable', () async {
      final mrNoDisplayName = buildUser(uid: 'rep2', email: null, displayName: null);
      when(() => repository.startSession(
            employeeUid: any(named: 'employeeUid'),
            username: any(named: 'username'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async => 'session2');

      await service.handleAppResumed(mrNoDisplayName);

      verify(() => repository.startSession(
            employeeUid: 'rep2',
            username: 'rep2',
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).called(1);
    });

    test('a second resume while a session is already active does not start another one', () async {
      final mr = buildUser(uid: 'rep1');
      when(() => repository.startSession(
            employeeUid: any(named: 'employeeUid'),
            username: any(named: 'username'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async => 'session1');

      await service.handleAppResumed(mr);
      await service.handleAppResumed(mr);

      verify(() => repository.startSession(
            employeeUid: any(named: 'employeeUid'),
            username: any(named: 'username'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).called(1);
    });

    test('records no location when the location lookup fails, without blocking the session', () async {
      when(() => geolocatorPlatform.checkPermission()).thenAnswer((_) async => LocationPermission.denied);
      when(() => geolocatorPlatform.requestPermission()).thenAnswer((_) async => LocationPermission.denied);
      final mr = buildUser(uid: 'rep1');
      when(() => repository.startSession(
            employeeUid: any(named: 'employeeUid'),
            username: any(named: 'username'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async => 'session1');

      await service.handleAppResumed(mr);

      verify(() => repository.startSession(
            employeeUid: 'rep1',
            username: any(named: 'username'),
            latitude: null,
            longitude: null,
          )).called(1);
    });
  });

  group('handleAppPaused', () {
    test('closes the active session', () async {
      final mr = buildUser(uid: 'rep1');
      when(() => repository.startSession(
            employeeUid: any(named: 'employeeUid'),
            username: any(named: 'username'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async => 'session1');
      when(() => repository.closeSession('session1')).thenAnswer((_) async {});
      await service.handleAppResumed(mr);

      await service.handleAppPaused();

      verify(() => repository.closeSession('session1')).called(1);
    });

    test('does nothing when there is no active session', () async {
      await service.handleAppPaused();

      verifyNever(() => repository.closeSession(any()));
    });

    test('a resume after a pause starts a brand-new session', () async {
      final mr = buildUser(uid: 'rep1');
      var callCount = 0;
      when(() => repository.startSession(
            employeeUid: any(named: 'employeeUid'),
            username: any(named: 'username'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async => 'session${++callCount}');
      when(() => repository.closeSession(any())).thenAnswer((_) async {});

      await service.handleAppResumed(mr);
      await service.handleAppPaused();
      await service.handleAppResumed(mr);

      verify(() => repository.startSession(
            employeeUid: any(named: 'employeeUid'),
            username: any(named: 'username'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).called(2);
      verify(() => repository.closeSession('session1')).called(1);
    });
  });
}
