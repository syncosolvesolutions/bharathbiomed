import 'dart:async';

import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:bharathbiomedpharma/data/repositories/admin_notifications_repository.dart';
import 'package:bharathbiomedpharma/domain/models/admin_notification.dart';
import 'package:bharathbiomedpharma/features/admin/admin_notifications_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAdminNotificationsRepository extends Mock implements AdminNotificationsRepository {}

void main() {
  late MockAdminNotificationsRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockAdminNotificationsRepository();
    container = ProviderContainer(
      overrides: [adminNotificationsRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() => container.dispose());

  const read = AdminNotification(id: 'n1', employeeUid: 'e1', employeeName: 'Rajesh', message: 'DOB set', read: true);
  const unread1 =
      AdminNotification(id: 'n2', employeeUid: 'e2', employeeName: 'Priya', message: 'DOB changed', read: false);
  const unread2 =
      AdminNotification(id: 'n3', employeeUid: 'e3', employeeName: 'Amit', message: 'DOB set', read: false);

  test('unreadAdminNotificationsCountProvider counts only unread notifications', () async {
    when(() => repository.watchAll()).thenAnswer((_) => Stream.value([read, unread1, unread2]));

    await container.read(adminNotificationsProvider.future);

    expect(container.read(unreadAdminNotificationsCountProvider), 2);
  });

  test('unreadAdminNotificationsCountProvider is zero when every notification is already read', () async {
    when(() => repository.watchAll()).thenAnswer((_) => Stream.value([read]));

    await container.read(adminNotificationsProvider.future);

    expect(container.read(unreadAdminNotificationsCountProvider), 0);
  });

  test('unreadAdminNotificationsCountProvider is zero before the stream has emitted, not an error', () {
    when(() => repository.watchAll()).thenAnswer((_) => const Stream.empty());

    expect(container.read(unreadAdminNotificationsCountProvider), 0);
  });

  test('unreadAdminNotificationsCountProvider updates as the underlying stream emits new snapshots', () async {
    final controller = StreamController<List<AdminNotification>>();
    addTearDown(controller.close);
    when(() => repository.watchAll()).thenAnswer((_) => controller.stream);

    final sub = container.listen(unreadAdminNotificationsCountProvider, (previous, next) {});
    controller.add([unread1]);
    await Future<void>.delayed(Duration.zero);
    expect(sub.read(), 1);

    controller.add([unread1, unread2]);
    await Future<void>.delayed(Duration.zero);
    expect(sub.read(), 2);
  });
}
