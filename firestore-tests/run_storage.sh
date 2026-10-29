#!/bin/sh
# Storage security-rules tests (emulators only, demo project).
# One-time: (cd firestore-tests && npm install)
set -e
cd "$(dirname "$0")/.."
exec firebase emulators:exec \
  --config firebase.storage-test.json \
  --only auth,firestore,storage \
  --project demo-skillnova-rules \
  "node firestore-tests/storage.test.mjs"
