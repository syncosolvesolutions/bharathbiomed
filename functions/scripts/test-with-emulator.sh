#!/usr/bin/env bash
set -euo pipefail

# Runs the Cloud Functions Jest suite against a local Firestore emulator.
#
# The emulator needs a JDK 21+. This machine's ambient JAVA_HOME/default
# `java` is intentionally left on an older version (17) — this script always
# overrides JAVA_HOME to 21 for its own subshell only, regardless of
# whatever JAVA_HOME the calling shell already had set, and never touches
# the machine-wide default. Set BBP_JAVA21_HOME yourself before calling this
# script if 21 lives somewhere other than the two spots checked below.
cd "$(dirname "$0")/.."

JAVA21_CANDIDATE="${BBP_JAVA21_HOME:-}"
if [ -z "$JAVA21_CANDIDATE" ]; then
  JAVA21_CANDIDATE="$(brew --prefix openjdk@21 2>/dev/null || true)"
fi
if [ -z "$JAVA21_CANDIDATE" ] || [ ! -x "$JAVA21_CANDIDATE/bin/java" ]; then
  JAVA21_CANDIDATE="/opt/homebrew/opt/openjdk@21"
fi
export JAVA_HOME="$JAVA21_CANDIDATE"
export PATH="$JAVA_HOME/bin:$PATH"

echo "Using JAVA_HOME=$JAVA_HOME ($("$JAVA_HOME/bin/java" -version 2>&1 | head -1))"

npm run build
exec firebase emulators:exec --only firestore --project demo-bharathbiomedpharma "npx jest --runInBand $*"
