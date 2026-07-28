import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Entry point for a manager's view of their own reporting-chain downline
/// (or, for a `view_global_data` holder, everyone) — usage/location and
/// doctor-visit-log reports. Reachable by any signed-in employee; both
/// screens behind it simply show an empty state if the signed-in user
/// doesn't actually manage anyone (see `resolveVisibleEmployees`).
class TeamHomeScreen extends StatelessWidget {
  const TeamHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              subtitle: const Text('Approve, reject, dispatch, and invoice orders from your team.'),
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
        ],
      ),
    );
  }
}
