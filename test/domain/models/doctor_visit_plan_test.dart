import 'package:bharathbiomedpharma/domain/models/doctor_visit_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DoctorVisitPlan.fromJson/toJson', () {
    test('round-trips status and approval fields', () {
      final plan = DoctorVisitPlan.fromJson('mr1', {
        'monday': ['d1', 'd2'],
        'status': 'approved',
        'approvedByUid': 'mgr1',
        'rejectedReason': null,
      });

      expect(plan.status, VisitPlanStatus.approved);
      expect(plan.approvedByUid, 'mgr1');
      expect(plan.forWeekday('monday'), ['d1', 'd2']);

      final json = plan.toJson();
      expect(json['status'], 'approved');
      expect(json['approvedByUid'], 'mgr1');
    });

    test('defaults to draft status for a legacy doc with no status field', () {
      final plan = DoctorVisitPlan.fromJson('mr1', {'monday': ['d1']});
      expect(plan.status, VisitPlanStatus.draft);
    });
  });

  group('copyWithWeekday', () {
    test('preserves the current approval status rather than resetting it', () {
      const plan = DoctorVisitPlan(mrUid: 'mr1', status: VisitPlanStatus.approved, approvedByUid: 'mgr1');
      final updated = plan.copyWithWeekday('monday', ['d1']);
      expect(updated.status, VisitPlanStatus.approved);
      expect(updated.approvedByUid, 'mgr1');
    });
  });

  group('copyAsPending', () {
    test('sets status to pending and clears any previous decision', () {
      const plan = DoctorVisitPlan(
        mrUid: 'mr1',
        doctorIdsByWeekday: {'monday': ['d1']},
        status: VisitPlanStatus.rejected,
        approvedByUid: 'mgr1',
        rejectedReason: 'redo it',
      );
      final pending = plan.copyAsPending();
      expect(pending.status, VisitPlanStatus.pending);
      expect(pending.approvedByUid, isNull);
      expect(pending.rejectedReason, isNull);
      expect(pending.forWeekday('monday'), ['d1']);
    });
  });
}
