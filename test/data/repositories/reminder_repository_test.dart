import 'package:bharathbiomedpharma/data/remote/reminder_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/reminder_repository.dart';
import 'package:bharathbiomedpharma/domain/models/reminder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockReminderRemoteDataSource extends Mock implements ReminderRemoteDataSource {}

void main() {
  late MockReminderRemoteDataSource remote;
  late ReminderRepository repository;

  final reminder = Reminder(
    id: 'r1',
    ownerUid: 'mr1',
    ownerName: 'Rajesh',
    createdByUid: 'mr1',
    createdByName: 'Rajesh',
    title: 'Follow up with Dr. Verma',
    dueAt: DateTime(2026, 8, 1),
  );

  setUp(() {
    remote = MockReminderRemoteDataSource();
    repository = ReminderRepository(remote: remote);
  });

  test('watchFor delegates to the remote data source', () {
    when(() => remote.watchFor('mr1')).thenAnswer((_) => Stream.value([reminder]));

    expect(repository.watchFor('mr1'), emits([reminder]));
  });

  test('create delegates to the remote data source', () async {
    when(() => remote.create(reminder)).thenAnswer((_) async {});

    await repository.create(reminder);

    verify(() => remote.create(reminder)).called(1);
  });

  test('setCompleted delegates to the remote data source', () async {
    when(() => remote.setCompleted('r1', true)).thenAnswer((_) async {});

    await repository.setCompleted('r1', true);

    verify(() => remote.setCompleted('r1', true)).called(1);
  });

  test('delete delegates to the remote data source', () async {
    when(() => remote.delete('r1')).thenAnswer((_) async {});

    await repository.delete('r1');

    verify(() => remote.delete('r1')).called(1);
  });
}
