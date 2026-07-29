import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/permission.dart';
import 'team_access.dart';

/// Entry point for a manager's view of their own reporting-chain downline
/// (or, for a `view_global_data` holder, everyone): usage/location,
/// doctor-visit-log reports, the order workflow queue, team targets, RCPA
/// entries, expense-claim approvals, visit-plan approvals, Doctor/Agency-
/// Pharmacy request reviews (for an `approve_requests` holder — see below),
/// and the UCPMP compliance dashboard. Reachable by any signed-in employee;
/// every screen behind it simply shows an empty state if the signed-in user
/// doesn't actually manage anyone (see `resolveVisibleEmployees`) or lacks
/// the specific permission that screen's actions need (e.g.
/// `approve_expenses`).
class TeamHomeScreen extends ConsumerWidget {
  const TeamHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canApproveRequests = ref.watch(hasPermissionProvider(Permission.approveRequests));

    return Scaffold(
      appBar: AppBar(title: const Text('My Team')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Usage & Location'),
              subtitle: const Text("See your team's app usage sessions and last known location."),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.push('/team/usage'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_hospital_outlined),
              title: const Text('Visit Logs'),
              subtitle: const Text("See your team's logged doctor visits and feedback."),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.push('/team/visit-logs'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Order Workflow'),
              subtitle: const Text('Approve, reject, and dispatch orders from your team.'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.push('/team/orders'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.track_changes_outlined),
              title: const Text('Team Targets'),
              subtitle: const Text("Set and track your team's monthly targets."),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.push('/team/targets'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('RCPA Entries'),
              subtitle: const Text("See your team's retail chemist prescription audits."),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.push('/team/rcpa'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.request_page_outlined),
              title: const Text('Expense Claims'),
              subtitle: const Text("Approve or reject your team's TA/DA expense claims."),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.push('/team/expenses'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Visit Plan Approvals'),
              subtitle: const Text("Review your team's submitted weekly beat/route plans."),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.push('/team/visit-plans'),
            ),
          ),
          if (canApproveRequests) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.local_hospital_outlined),
                title: const Text('Doctor Requests'),
                subtitle: const Text('Review proposed doctor additions/edits from any MR.'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/doctor-requests'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('Agency / Pharmacy Requests'),
                subtitle: const Text('Review proposed new agencies/pharmacies from any MR.'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/entity-requests'),
              ),
            ),
          ],
          Card(
            child: ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: const Text('Compliance Dashboard'),
              subtitle: const Text('Per-doctor UCPMP gift/sponsorship totals for this year.'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.push('/team/compliance'),
            ),
          ),
        ],
      ),
    );
  }
}
