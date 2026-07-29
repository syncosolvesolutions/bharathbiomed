import 'package:bharathbiomedpharma/data/remote/invoice_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/invoice_repository.dart';
import 'package:bharathbiomedpharma/domain/models/invoice.dart';
import 'package:bharathbiomedpharma/domain/models/payment.dart';
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

  test('fetchPayments delegates to the remote data source', () async {
    const payment = Payment(id: 'p1', invoiceId: 'i1', amount: 25, recordedByUid: 'admin1');
    when(() => remote.fetchPayments('i1')).thenAnswer((_) async => [payment]);
    expect(await repository.fetchPayments('i1'), [payment]);
  });

  test('recordPayment delegates to the remote data source', () async {
    when(() => remote.recordPayment('i1', amount: 25, notes: 'partial payment')).thenAnswer((_) async {});
    await repository.recordPayment('i1', amount: 25, notes: 'partial payment');
    verify(() => remote.recordPayment('i1', amount: 25, notes: 'partial payment')).called(1);
  });
}
