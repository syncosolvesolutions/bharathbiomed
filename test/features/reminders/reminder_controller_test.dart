import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:bharathbiomedpharma/data/repositories/reminder_repository.dart';
import 'package:bharathbiomedpharma/domain/models/reminder.dart';
import 'package:bharathbiomedpharma/features/auth/auth_controller.dart';
import 'package:bharathbiomedpharma/features/reminders/reminder_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockReminderRepository extends Mock implements ReminderRepository {}

class MockUser extends Mock implements User {}

class _StubAuthController extends AuthController {
  _StubAuthController(this._user);
  final User? _user;
  @override
  Future<User?> build() async => _user;
}

void main() {
  late MockReminderRepository repository;

  final reminder = Reminder(
    id: 'r1',
    ownerUid: 'mr1',
    ownerName: 'Rajesh',
    createdByUid: 'mr1',
    createdByName: 'Rajesh',
    title: 'Follow up',
    dueAt: DateTime(2026, 8, 1),
  );

  Future<ProviderContainer> buildContainer(User? user) async {
    repository = MockReminderRepository();
    final container = ProviderContainer(overrides: [
      reminderRepositoryProvider.overrideWithValue(repository),
      authControllerProvider.overrideWith(() => _StubAuthController(user)),
    ]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    return container;
  }

  test('never touches the repository when signed out (the empty stream never resolves the provider)', () async {
    final container = await buildContainer(null);

    // The empty stream this falls back to (see myRemindersProvider's
    // uid==null branch) never emits, so the provider just stays loading
    // forever by design rather than resolving to `[]` — there's nothing for
    // a screen watching it to show, same as before anyone signed in.
    // Awaiting `.future` here would hang for the same reason, so this reads
    // the synchronous AsyncValue instead of the Future.
    expect(container.read(myRemindersProvider), const AsyncLoading<List<Reminder>>());
    verifyNever(() => repository.watchFor(any()));
  });

  test('watches the signed-in user\'s own reminders', () async {
    final user = MockUser();
    when(() => user.uid).thenReturn('mr1');
    final container = await buildContainer(user);
    when(() => repository.watchFor('mr1')).thenAnswer((_) => Stream.value([reminder]));

    final result = await container.read(myRemindersProvider.future);

    expect(result, [reminder]);
  });
}
