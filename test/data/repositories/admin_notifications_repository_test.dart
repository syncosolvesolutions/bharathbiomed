import 'package:bharathbiomedpharma/data/remote/admin_notifications_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/admin_notifications_repository.dart';
import 'package:bharathbiomedpharma/domain/models/admin_notification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAdminNotificationsRemoteDataSource extends Mock implements AdminNotificationsRemoteDataSource {}

void main() {
  late MockAdminNotificationsRemoteDataSource remote;
  late AdminNotificationsRepository repository;

  const notification =
      AdminNotification(id: 'n1', employeeUid: 'e1', employeeName: 'Rajesh', message: 'DOB set', read: false);

  setUp(() {
    remote = MockAdminNotificationsRemoteDataSource();
    repository = AdminNotificationsRepository(remote: remote);
  });

  test('watchAll delegates to the remote data source', () {
    when(() => remote.watchAll()).thenAnswer((_) => Stream.value([notification]));

    expect(repository.watchAll(), emits([notification]));
  });

  test('markRead delegates to the remote data source', () async {
    when(() => remote.markRead('n1')).thenAnswer((_) async {});

    await repository.markRead('n1');

    verify(() => remote.markRead('n1')).called(1);
  });
}
