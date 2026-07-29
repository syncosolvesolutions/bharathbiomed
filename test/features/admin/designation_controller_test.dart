import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:bharathbiomedpharma/data/repositories/designation_repository.dart';
import 'package:bharathbiomedpharma/domain/models/designation.dart';
import 'package:bharathbiomedpharma/domain/models/permission.dart';
import 'package:bharathbiomedpharma/features/admin/designation_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDesignationRepository extends Mock implements DesignationRepository {}

void main() {
  late MockDesignationRepository repository;
  late ProviderContainer container;

  const designation = Designation(
    id: 'd1',
    name: 'Medical Representative',
    category: DesignationCategory.field,
    hierarchyLevel: 0,
    permissions: ['create_orders'],
  );

  setUpAll(() {
    registerFallbackValue(DesignationCategory.field);
  });

  setUp(() {
    repository = MockDesignationRepository();
    container = ProviderContainer(
      overrides: [designationRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() => container.dispose());

  test('build fetches every designation from the repository', () async {
    when(() => repository.fetchAll()).thenAnswer((_) async => [designation]);

    final result = await container.read(designationControllerProvider.future);

    expect(result, [designation]);
  });

  test('save creates a new designation then refreshes the list', () async {
    when(() => repository.fetchAll()).thenAnswer((_) async => []);
    await container.read(designationControllerProvider.future);

    when(() => repository.save(
          id: any(named: 'id'),
          name: any(named: 'name'),
          category: any(named: 'category'),
          hierarchyLevel: any(named: 'hierarchyLevel'),
          parentDesignationId: any(named: 'parentDesignationId'),
          permissions: any(named: 'permissions'),
          downlineDesignationIds: any(named: 'downlineDesignationIds'),
        )).thenAnswer((_) async => 'd1');
    when(() => repository.fetchAll()).thenAnswer((_) async => [designation]);

    await container.read(designationControllerProvider.notifier).save(
          name: 'Medical Representative',
          category: DesignationCategory.field,
          hierarchyLevel: 0,
          permissions: {Permission.createOrders},
          downlineDesignationIds: {},
        );

    expect(container.read(designationControllerProvider).value, [designation]);
    verify(() => repository.save(
          id: null,
          name: 'Medical Representative',
          category: DesignationCategory.field,
          hierarchyLevel: 0,
          parentDesignationId: null,
          permissions: {Permission.createOrders},
          downlineDesignationIds: {},
        )).called(1);
  });

  test('delete removes a designation then refreshes the list', () async {
    when(() => repository.fetchAll()).thenAnswer((_) async => [designation]);
    await container.read(designationControllerProvider.future);

    when(() => repository.delete('d1')).thenAnswer((_) async {});
    when(() => repository.fetchAll()).thenAnswer((_) async => []);

    await container.read(designationControllerProvider.notifier).delete('d1');

    expect(container.read(designationControllerProvider).value, isEmpty);
    verify(() => repository.delete('d1')).called(1);
  });

  test('a failing refresh surfaces as an AsyncError state, not a thrown exception', () async {
    when(() => repository.fetchAll()).thenAnswer((_) async => [designation]);
    await container.read(designationControllerProvider.future);

    when(() => repository.delete('d1')).thenAnswer((_) async {});
    when(() => repository.fetchAll()).thenThrow(Exception('network error'));

    await container.read(designationControllerProvider.notifier).delete('d1');

    expect(container.read(designationControllerProvider).hasError, isTrue);
  });
}
