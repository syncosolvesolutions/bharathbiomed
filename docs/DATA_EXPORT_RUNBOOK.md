# Per-tenant data export / backup runbook

A buyer-trust deliverable: any tenant can get their own data out on
request, independent of this app's UI. This is a runbook (commands to run
by hand when needed), not automated in-app — exporting a customer's full
database is not something to trigger from a button in the app itself.

**Why this is simple for this app specifically**: per the white-label
design (`core/tenant/tenant_config.dart`), each tenant gets their own
Firebase project (per-tenant build & deploy, not a shared multi-tenant
backend — see the roadmap plan's Phase 1 decision). That means "export
tenant X's data" is just "export project X's Firestore/Storage" — there's
no need to filter a shared database down to one tenant's rows.

## Firestore: full managed export

Google Cloud's managed Firestore export is the correct tool — no custom
script needed, and it captures every collection consistently.

```bash
# One-time, per machine: authenticate and select the tenant's project.
gcloud auth login
gcloud config set project <tenant-firebase-project-id>

# Create a GCS bucket for exports if the project doesn't already have one
# (bucket names are globally unique — pick something project-specific).
gsutil mb -l <region, e.g. asia-south1> gs://<tenant-project-id>-firestore-exports

# Export everything, timestamped.
gcloud firestore export gs://<tenant-project-id>-firestore-exports/export-$(date +%Y%m%d-%H%M%S)
```

This produces a full, consistent snapshot in Google's native export format
(not plain JSON — see "Handing the data to the customer" below for
converting it to something they can actually open). The export runs
server-side; it does not require downloading anything to your machine
first, and doesn't affect the live app (reads happen on Firestore's
managed infrastructure, not against the same read quota the app uses).

## Storage: product/employee photos

Firestore's export above does **not** include Firebase Storage (product
images, employee photos — anything uploaded via `image_uploader.dart`/
`PhotoPickerField`). Copy the Storage bucket separately:

```bash
gsutil -m cp -r gs://<tenant-project-id>.firebasestorage.app gs://<tenant-project-id>-firestore-exports/storage-$(date +%Y%m%d)
```

## Handing the data to the customer

The `gcloud firestore export` output is in Firestore's own binary export
format (LevelDB-based), not something a customer can open in a
spreadsheet. Two options depending on what they actually need:

1. **They just want proof they can get their data, or plan to re-import it
   into another Firestore project** — hand them the exported GCS path
   directly (`gsutil` access or a signed URL); `gcloud firestore import`
   can load it into any Firestore project, including a plain non-Firebase
   GCP project they control.
2. **They want human-readable data** (e.g. for a records request, or to
   move to a non-Firestore system) — export each collection to JSON/CSV
   instead. There's no built-in `gcloud` command for this; the
   [`firestore-export-import`](https://www.npmjs.com/package/firestore-export-import)
   npm package (or a short script using the Admin SDK already vendored in
   `functions/`) can walk each top-level collection
   (`Products`, `Users`, `Orders`, `Invoices`, `ExpenseClaims`,
   `LeaveRequests`, `RcpaEntries`, `ComplianceLogs`, ...) and dump it to
   JSON. This is scripted per-request, not a standing tool in this repo —
   write it if/when an actual export request comes in, since the exact
   shape a customer wants (all collections? one date range? which
   fields?) varies per request.

## What this does NOT cover

- **Deleting a tenant's data on request** (the inverse — a right-to-
  deletion request) is a separate, higher-stakes runbook this doc doesn't
  attempt; deleting a live Firebase project's data needs its own careful
  process (and sign-off), not a checklist item alongside a routine export.
- **Automating a recurring backup schedule** — the commands above are
  manual/on-demand. If a tenant wants scheduled backups, Google Cloud
  supports scheduling `gcloud firestore export` via Cloud Scheduler +
  Cloud Functions, which is additional setup per tenant, not something
  this runbook configures by default.
