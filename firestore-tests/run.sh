#!/bin/sh
# Runs the Firestore security-rules tests against throwaway local emulators
# (config: ../firebase.rules-test.json, non-default ports). Uses a demo-
# project id, so nothing can reach production Firebase.
# Requires the Firebase CLI, Java 11+ and Node 18+.
set -e
cd "$(dirname "$0")/.."
exec firebase emulators:exec \
  --config firebase.rules-test.json \
  --only auth,firestore \
  --project demo-skillnova-rules \
  "node --test firestore-tests/rules.test.mjs"
