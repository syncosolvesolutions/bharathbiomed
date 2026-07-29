import 'package:bharathbiomedpharma/data/remote/auth_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

void main() {
  late MockAuthRemoteDataSource remote;
  late AuthRepository repository;

  setUp(() {
    remote = MockAuthRemoteDataSource();
    repository = AuthRepository(remote: remote);
  });

  group('signIn', () {
    test('passes a real email through to the remote data source unchanged', () async {
      when(() => remote.signInWithEmailAndPassword(any(), any())).thenAnswer((_) async => null);

      await repository.signIn('bharathbiomedpharma@gmail.com', 'secret');

      verify(() => remote.signInWithEmailAndPassword('bharathbiomedpharma@gmail.com', 'secret')).called(1);
    });

    test('translates a bare username into its synthetic MR email before signing in', () async {
      when(() => remote.signInWithEmailAndPassword(any(), any())).thenAnswer((_) async => null);

      await repository.signIn('rajesh_kumar', 'secret');

      verify(() => remote.signInWithEmailAndPassword(
            'mr-rajesh_kumar@bharathbiomed-14368.firebaseapp.com',
            'secret',
          )).called(1);
    });
  });
}
