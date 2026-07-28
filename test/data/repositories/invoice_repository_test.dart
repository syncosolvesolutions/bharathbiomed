import 'package:bharathbiomedpharma/data/remote/invoice_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/invoice_repository.dart';
import 'package:bharathbiomedpharma/domain/models/invoice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInvoiceRemoteDataSource extends Mock implements InvoiceRemoteDataSource {}

void main() {
  late MockInvoiceRemoteDataSource remote;
  late InvoiceRepository repository;

  const invoice = Invoice(
    id: 'i1',
    orderId: 'o1',
    invoiceNumber: 'INV-000001',
    agencyId: 'a1',
    agencyName: 'MedSupply Co',
    items: [],
    totalValue: 50,
  );

  setUp(() {
    remote = MockInvoiceRemoteDataSource();
    repository = InvoiceRepository(remote: remote);
  });

  test('fetchAll delegates to the remote data source', () async {
    when(() => remote.fetchAll()).thenAnswer((_) async => [invoice]);
    expect(await repository.fetchAll(), [invoice]);
  });

  test('generate delegates to the remote data source', () async {
    when(() => remote.generate('o1')).thenAnswer((_) async {});
    await repository.generate('o1');
    verify(() => remote.generate('o1')).called(1);
  });
}
