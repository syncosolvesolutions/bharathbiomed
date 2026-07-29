#!/usr/bin/env bash
# Onboards a new pharma-company tenant onto this codebase: regenerates every
# tenant-specific file from tenants/<tenantId>/, then produces a branded
# release build. This is the actual "sell to a second customer" workflow —
# see the "Roadmap: white-label + full gap closure" plan, Phase 1.
#
# Usage: scripts/new_tenant.sh <tenantId> [--build]
#
# Prerequisites (once per tenant, not automated here — each needs a human
# decision or an interactive login this script shouldn't silently perform):
#   1. Create tenants/<tenantId>/tenant.json (copy an existing tenant's and
#      edit every value — see tenants/bharathbiomed/tenant.json).
#   2. Create tenants/<tenantId>/tenant.properties (applicationId, appLabel
#      — see tenants/bharathbiomed/tenant.properties).
#   3. Create/target that tenant's Firebase project and run
#      `flutterfire configure --project=<firebaseProjectId>` from the repo
#      root — this regenerates lib/firebase_options.dart and downloads that
#      project's android/app/google-services.json and
#      ios/Runner/GoogleService-Info.plist. Requires an interactive
#      `firebase login` first if not already authenticated.
#   4. Add tenants/<tenantId>/logo.png (square, for the launcher icon) and
#      tenants/<tenantId>/splash_logo.png (for the native splash screen).
#
# What this script does automate from there:
#   - Regenerates lib/core/tenant/tenant_config.dart, the admin-email blocks
#     in functions/src/adminAccess.ts and firestore.rules, and
#     docs/TERMS_AND_CONDITIONS.md / docs/PRIVACY_POLICY.md
#     (scripts/apply_tenant.dart).
#   - Copies tenants/<tenantId>/tenant.properties to android/tenant.properties
#     so the next Android build picks up that tenant's applicationId/app
#     label (see android/app/build.gradle.kts).
#   - Regenerates the launcher icon and native splash screen from that
#     tenant's logo (flutter_launcher_icons / flutter_native_splash).
#   - With --build: also runs `flutter build appbundle --release` at the end.
#
# Firebase project switching (`firebase use <project>`) and the Cloud
# Functions/Firestore-rules deploy for that project are deliberately left
# as separate manual commands — this script only prepares the Flutter/
# Android build, it doesn't touch what's live on any Firebase project.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: scripts/new_tenant.sh <tenantId> [--build]" >&2
  exit 64
fi

tenant_id="$1"
do_build="false"
if [[ "${2:-}" == "--build" ]]; then
  do_build="true"
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

tenant_dir="tenants/$tenant_id"
if [[ ! -f "$tenant_dir/tenant.json" ]]; then
  echo "No such tenant config: $tenant_dir/tenant.json" >&2
  exit 66
fi

echo "==> Applying tenant.json (tenant_config.dart, adminAccess.ts, firestore.rules, legal docs)"
dart run scripts/apply_tenant.dart "$tenant_id"

if [[ -f "$tenant_dir/tenant.properties" ]]; then
  echo "==> Copying tenant.properties to android/tenant.properties"
  cp "$tenant_dir/tenant.properties" android/tenant.properties
else
  echo "==> No $tenant_dir/tenant.properties found — Android build will keep using its fallback identity." >&2
fi

if [[ -f "$tenant_dir/google-services.json" ]]; then
  echo "==> Copying this tenant's google-services.json into place"
  cp "$tenant_dir/google-services.json" android/app/google-services.json
else
  echo "==> No $tenant_dir/google-services.json — run 'flutterfire configure --project=<id>' for this tenant first." >&2
fi

if [[ -f "$tenant_dir/GoogleService-Info.plist" ]]; then
  echo "==> Copying this tenant's GoogleService-Info.plist into place"
  cp "$tenant_dir/GoogleService-Info.plist" ios/Runner/GoogleService-Info.plist
fi

if [[ -f "$tenant_dir/logo.png" ]]; then
  echo "==> Regenerating launcher icon from $tenant_dir/logo.png"
  icons_config=$(mktemp -t flutter_launcher_icons_XXXX.yaml)
  cat > "$icons_config" <<EOF
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "$tenant_dir/logo.png"
  min_sdk_android: 21
EOF
  dart run flutter_launcher_icons -f "$icons_config"
  rm -f "$icons_config"
else
  echo "==> No $tenant_dir/logo.png — keeping the current launcher icon." >&2
fi

if [[ -f "$tenant_dir/splash_logo.png" ]]; then
  echo "==> Regenerating native splash from $tenant_dir/splash_logo.png"
  splash_config=$(mktemp -t flutter_native_splash_XXXX.yaml)
  # tenant.json's primaryColorHex is "0xAARRGGBB" (see TenantConfig.primaryColorValue);
  # flutter_native_splash wants a plain "#RRGGBB", so strip the "0x" and alpha byte.
  primary_hex=$(grep -o '"primaryColorHex"[[:space:]]*:[[:space:]]*"0x[0-9A-Fa-f]*"' "$tenant_dir/tenant.json" \
    | grep -o '0x[0-9A-Fa-f]*' | sed -E 's/^0x..(.*)$/#\1/')
  if [[ -z "$primary_hex" ]]; then
    echo "==> Could not read primaryColorHex from $tenant_dir/tenant.json, defaulting splash color to #3470B2." >&2
    primary_hex="#3470B2"
  fi
  cat > "$splash_config" <<EOF
flutter_native_splash:
  color: "$primary_hex"
  image: "$tenant_dir/splash_logo.png"
EOF
  dart run flutter_native_splash:create --path "$splash_config"
  rm -f "$splash_config"
else
  echo "==> No $tenant_dir/splash_logo.png — keeping the current splash screen." >&2
fi

echo "==> Still manual: 'firebase use <project>' + 'firebase deploy --only functions,firestore:rules' for this tenant's Firebase project."

if [[ "$do_build" == "true" ]]; then
  echo "==> Building release app bundle"
  flutter build appbundle --release
fi

echo "==> Done. Applied tenant: $tenant_id"
