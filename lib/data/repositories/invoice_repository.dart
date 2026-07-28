import '../../domain/models/invoice.dart';
import '../remote/invoice_remote_data_source.dart';

/// Invoices — read-only from the client (see [InvoiceRemoteDataSource]);
/// always a live Firestore read, same reasoning as [AdminCatalogController]:
/// invoicing is a low-frequency, connectivity-assumed admin/office action.
class InvoiceRepository {
  InvoiceRepository({InvoiceRemoteDataSource? remote}) : _remote = remote ?? InvoiceRemoteDataSource();

  final InvoiceRemoteDataSource _remote;

  Future<List<Invoice>> fetchAll() => _remote.fetchAll();

  /// `manage_invoices`-gated Cloud Function.
  Future<void> generate(String orderId) => _remote.generate(orderId);
}
