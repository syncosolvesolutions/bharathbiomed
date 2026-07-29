import 'package:flutter/foundation.dart';

import '../../domain/models/sales_target.dart';
import '../remote/sales_target_remote_data_source.dart';

/// Monthly targets — always a live Firestore read/write (connectivity-
/// assumed, same reasoning as [EntityChangeRequestRepository]'s review
/// path: setting a target is a manager action, not a field-with-no-signal
/// action).
class SalesTargetRepository {
  SalesTargetRepository({SalesTargetRemoteDataSource? remote}) : _remote = remote ?? SalesTargetRemoteDataSource();

  final SalesTargetRemoteDataSource _remote;

  /// `manage_targets`-gated (or global visibility/admin) in firestore.rules,
  /// further restricted to [employeeUid] being in the caller's own
  /// reporting-chain downline.
  Future<void> setTarget({
    required String employeeUid,
    required String period,
    required double targetValue,
    required String createdByUid,
  }) {
    debugPrint('SalesTargetRepository.setTarget: employeeUid=$employeeUid period=$period targetValue=$targetValue');
    return _remote.setTarget(
      employeeUid: employeeUid,
      period: period,
      targetValue: targetValue,
      createdByUid: createdByUid,
    );
  }

  Future<SalesTarget?> fetchForEmployee(String employeeUid, String period) =>
      _remote.fetchForEmployee(employeeUid, period);

  Future<List<SalesTarget>> fetchForEmployees(List<String> employeeUids, String period) =>
      _remote.fetchForEmployees(employeeUids, period);
}
