import 'package:bharathbiomedpharma/features/tracking/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockGeolocatorPlatform extends Mock with MockPlatformInterfaceMixin implements GeolocatorPlatform {}

void main() {
  late MockGeolocatorPlatform platform;
  late GeolocatorPlatform originalPlatform;
  late LocationService service;

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
    platform = MockGeolocatorPlatform();
    originalPlatform = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = platform;
    service = LocationService();
  });

  tearDown(() {
    GeolocatorPlatform.instance = originalPlatform;
  });

  test('returns the current position when permission is already granted and location is enabled', () async {
    when(() => platform.checkPermission()).thenAnswer((_) async => LocationPermission.whileInUse);
    when(() => platform.isLocationServiceEnabled()).thenAnswer((_) async => true);
    when(() => platform.getCurrentPosition(locationSettings: any(named: 'locationSettings')))
        .thenAnswer((_) async => position);

    final result = await service.getCurrentLocationBestEffort();

    expect(result, position);
    verifyNever(() => platform.requestPermission());
  });

  test('requests permission when initially denied, then proceeds if granted', () async {
    when(() => platform.checkPermission()).thenAnswer((_) async => LocationPermission.denied);
    when(() => platform.requestPermission()).thenAnswer((_) async => LocationPermission.whileInUse);
    when(() => platform.isLocationServiceEnabled()).thenAnswer((_) async => true);
    when(() => platform.getCurrentPosition(locationSettings: any(named: 'locationSettings')))
        .thenAnswer((_) async => position);

    final result = await service.getCurrentLocationBestEffort();

    expect(result, position);
    verify(() => platform.requestPermission()).called(1);
  });

  test('returns null without ever calling getCurrentPosition when permission stays denied', () async {
    when(() => platform.checkPermission()).thenAnswer((_) async => LocationPermission.denied);
    when(() => platform.requestPermission()).thenAnswer((_) async => LocationPermission.denied);

    final result = await service.getCurrentLocationBestEffort();

    expect(result, isNull);
    verifyNever(() => platform.isLocationServiceEnabled());
    verifyNever(() => platform.getCurrentPosition(locationSettings: any(named: 'locationSettings')));
  });

  test('returns null when permission is denied forever, without requesting again', () async {
    when(() => platform.checkPermission()).thenAnswer((_) async => LocationPermission.deniedForever);

    final result = await service.getCurrentLocationBestEffort();

    expect(result, isNull);
    verifyNever(() => platform.requestPermission());
  });

  test('returns null when permission is granted but the location service is disabled', () async {
    when(() => platform.checkPermission()).thenAnswer((_) async => LocationPermission.whileInUse);
    when(() => platform.isLocationServiceEnabled()).thenAnswer((_) async => false);

    final result = await service.getCurrentLocationBestEffort();

    expect(result, isNull);
    verifyNever(() => platform.getCurrentPosition(locationSettings: any(named: 'locationSettings')));
  });

  test('never throws — swallows a getCurrentPosition failure (e.g. a timeout) and returns null', () async {
    when(() => platform.checkPermission()).thenAnswer((_) async => LocationPermission.whileInUse);
    when(() => platform.isLocationServiceEnabled()).thenAnswer((_) async => true);
    when(() => platform.getCurrentPosition(locationSettings: any(named: 'locationSettings')))
        .thenThrow(Exception('timed out'));

    final result = await service.getCurrentLocationBestEffort();

    expect(result, isNull);
  });

  test('never throws — swallows a checkPermission platform failure and returns null', () async {
    when(() => platform.checkPermission()).thenThrow(Exception('platform unavailable'));

    final result = await service.getCurrentLocationBestEffort();

    expect(result, isNull);
  });
}
