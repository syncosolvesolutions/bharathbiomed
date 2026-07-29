# Compliance (UCPMP) feature

Logs what an MR gave a doctor (product sample, gift, sponsorship,
hospitality) and its value, for UCPMP (Uniform Code for Pharmaceutical
Marketing Practices) auditability — India's pharma marketing code
restricts/prohibits gifts to prescribers. This exists to make what
actually happened visible, not to authorize or encourage it. Structurally
close to `features/rcpa` (append-only, offline-first, no approval
workflow) — read that folder's pattern first; this note covers what's
different.

## Files

- `compliance_log_form_screen.dart` — doctor, category, date, value,
  optional description. `_save` only ever queues locally.
- `my_compliance_logs_screen.dart` / `my_compliance_logs_controller.dart` —
  the signed-in MR's own logged entries (route `/compliance`), read
  straight from the local queue (synced or not) — mirrors
  `MyRcpaEntriesController`, not the Firestore-backed "mine" controllers in
  `features/expenses`/`features/leave` (there's no server-side status to
  wait for here; it's a log, not a request).
- `compliance_dashboard_controller.dart` / `compliance_dashboard_screen.dart`
  — team view (route `/team/compliance`), scoped via
  `resolveVisibleEmployees`. **Aggregates by doctor, not by MR** — see
  `DoctorComplianceSummary`'s doc comment for why: the actual compliance
  question is "has this doctor received too much," regardless of which rep
  gave it.

## The limit is a dashboard flag, not a hard stop

`TenantConfig.ucpmpAnnualLimitPerDoctor` (see `core/tenant/tenant_config.dart`)
is checked by `DoctorComplianceSummary.isOverLimit` for the dashboard's
red-flag styling — it never blocks `ComplianceLogFormScreen` from saving.
An audit log that refused to record something over a limit would defeat
its own purpose: you want the record precisely when something crosses the
line, not a client-side guess about what should have happened. The default
tenant value is `0` — deliberately strict (flags any nonzero value) since
India's UCPMP guidance is that prescribers generally shouldn't receive
gifts at all; a tenant with an actual configured allowance sets a real
number.

## Not built

- No currency field anywhere in this app — `value` is a bare number, and
  the dashboard just prints it. If a tenant needs actual currency handling
  (formatting, multi-currency), that's new scope.
- No export/report generation (e.g. a PDF audit trail for a compliance
  officer) — see the roadmap's Phase 5 (reporting/exports), not built yet.
- No interaction with `features/leave`/`features/expenses` — a
  sponsorship logged here and a matching expense claim aren't linked.
