import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/order.dart';
import '../local/order_local_data_source.dart';
import '../remote/order_remote_data_source.dart';

/// An MR's placed orders, offline-first: [submit] only ever touches the
/// local queue (works standing in a pharmacy/agency visit with no signal);
/// [uploadPending] is what the sync pipeline calls to actually reach
/// Firestore. Once uploaded, live status (approved/dispatched/delivered) is
/// only ever read via [fetchMine]/[fetchPending] — mirrors
/// [DoctorChangeRequestRepository].
class OrderRepository {
  OrderRepository({OrderRemoteDataSource? remote, OrderLocalDataSource? local})
      : _remote = remote ?? OrderRemoteDataSource(),
        _local = local ?? OrderLocalDataSource();

  final OrderRemoteDataSource _remote;
  final OrderLocalDataSource _local;

  Future<void> submit(Order order) async {
    debugPrint('OrderRepository.submit: agencyId=${order.agencyId} items=${order.items.length}');
    final localId = const Uuid().v4();
    await _local.insert(localId, order.toCreateJson());
    debugPrint('OrderRepository.submit: queued localId=$localId');
  }

  Future<int> countPendingUpload() => _local.countUnsynced();

  /// Best-effort, called from the sync pipeline — never lets a partial
  /// failure lose already-queued orders (they just stay queued for the next
  /// sync attempt).
  Future<void> uploadPending() async {
    debugPrint('OrderRepository.uploadPending: checking for unsynced orders');
    final pending = await _local.getUnsynced();
    if (pending.isEmpty) {
      debugPrint('OrderRepository.uploadPending: nothing to upload');
      return;
    }
    debugPrint('OrderRepository.uploadPending: uploading ${pending.length} orders');
    final uploaded = <String>[];
    for (final order in pending) {
      try {
        await _remote.create(order.localId, order.data);
        uploaded.add(order.localId);
      } catch (error) {
        debugPrint('OrderRepository.uploadPending: failed localId=${order.localId} error=$error');
      }
    }
    await _local.markSynced(uploaded);
    debugPrint('OrderRepository.uploadPending: uploaded ${uploaded.length}/${pending.length}');
  }

  Future<List<Order>> fetchMine(String createdByUid) => _remote.fetchMine(createdByUid);

  Future<List<Order>> fetchAll() => _remote.fetchAll();

  Future<List<Order>> fetchForEmployees(List<String> employeeUids) => _remote.fetchForEmployees(employeeUids);

  /// `approve_orders`-gated in firestore.rules.
  Future<void> approve(String orderId, {required String approvedByUid}) =>
      _remote.approve(orderId, approvedByUid: approvedByUid);

  /// `approve_orders`-gated in firestore.rules.
  Future<void> reject(String orderId, {required String approvedByUid, String? reason}) =>
      _remote.reject(orderId, approvedByUid: approvedByUid, reason: reason);

  /// `dispatch_orders`-gated Cloud Function.
  Future<void> dispatch(String orderId) => _remote.dispatch(orderId);

  /// Ownership-scoped direct write — see [OrderRemoteDataSource.markDelivered].
  Future<void> markDelivered(String orderId) => _remote.markDelivered(orderId);
}
