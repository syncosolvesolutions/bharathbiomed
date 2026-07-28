import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/order.dart';

/// `Orders`: an MR creates one directly (low-privilege — firestore.rules
/// only lets them write their own `createdByUid`, `status: pending`);
/// approve/reject are also direct writes, gated by `approve_orders` +
/// reporting-chain membership (or global visibility). Dispatch and invoice
/// generation go through Cloud Functions instead, since both need an atomic
/// transaction against a second resource (`Products.stockQuantity`, an
/// invoice-number counter) that a plain client write can't safely do.
class OrderRemoteDataSource {
  OrderRemoteDataSource({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Order _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) => Order.fromJson(doc.id, doc.data());

  /// [localId] becomes the Firestore doc id, so a retried upload after a
  /// partial failure overwrites the same doc instead of duplicating it.
  Future<void> create(String localId, Map<String, dynamic> data) async {
    debugPrint('OrderRemoteDataSource.create: localId=$localId');
    await _firestore.collection('Orders').doc(localId).set({...data, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<List<Order>> fetchMine(String createdByUid) async {
    debugPrint('OrderRemoteDataSource.fetchMine: createdByUid=$createdByUid');
    final snapshot = await _firestore.collection('Orders').where('createdByUid', isEqualTo: createdByUid).get();
    final orders = snapshot.docs.map(_fromDoc).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return orders;
  }

  /// Every order — for an approver/dispatcher/invoicer with global
  /// visibility. The workflow screen filters to the non-terminal statuses
  /// (pending/approved/dispatched) itself; fetched unfiltered here since
  /// Firestore only allows one `whereIn`/equality-on-status filter per
  /// query and [fetchForEmployees] already needs its one `whereIn` for the
  /// uid scoping.
  Future<List<Order>> fetchAll() async {
    debugPrint('OrderRemoteDataSource.fetchAll: querying all orders');
    final snapshot = await _firestore.collection('Orders').get();
    final orders = snapshot.docs.map(_fromDoc).toList()
      ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
    return orders;
  }

  /// Every order created by exactly [employeeUids] — what a manager without
  /// global visibility must use instead, mirroring
  /// [UsageSessionRemoteDataSource.fetchRecentForEmployees]'s chunked-`whereIn`
  /// approach (Firestore caps `whereIn` at 30).
  Future<List<Order>> fetchForEmployees(List<String> employeeUids) async {
    debugPrint('OrderRemoteDataSource.fetchForEmployees: employeeUids=${employeeUids.length}');
    if (employeeUids.isEmpty) return [];

    const chunkSize = 30;
    final orders = <Order>[];
    for (var i = 0; i < employeeUids.length; i += chunkSize) {
      final chunk = employeeUids.skip(i).take(chunkSize).toList();
      final snapshot = await _firestore.collection('Orders').where('createdByUid', whereIn: chunk).get();
      orders.addAll(snapshot.docs.map(_fromDoc));
    }
    orders.sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
    return orders;
  }

  Future<void> approve(String orderId, {required String approvedByUid}) async {
    debugPrint('OrderRemoteDataSource.approve: orderId=$orderId');
    await _firestore.collection('Orders').doc(orderId).update({
      'status': 'approved',
      'approvedByUid': approvedByUid,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reject(String orderId, {required String approvedByUid, String? reason}) async {
    debugPrint('OrderRemoteDataSource.reject: orderId=$orderId');
    await _firestore.collection('Orders').doc(orderId).update({
      'status': 'rejected',
      'approvedByUid': approvedByUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'rejectedReason': reason,
    });
  }

  /// `dispatch_orders`-gated Cloud Function: transactionally verifies the
  /// order is `approved`, decrements each item's product stock, and marks
  /// the order `dispatched`.
  Future<void> dispatch(String orderId) async {
    debugPrint('OrderRemoteDataSource.dispatch: orderId=$orderId');
    await _functions.httpsCallable('dispatchOrder').call({'orderId': orderId});
  }
}
