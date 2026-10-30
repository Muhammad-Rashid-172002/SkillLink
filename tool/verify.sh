#!/bin/sh
# One-command verification for SkillNova. Run from the project root on your Mac:
#   sh tool/verify.sh
# Writes everything to _claude_tmp/verify.log (and prints a summary).
cd "$(dirname "$0")/.." || exit 1
mkdir -p _claude_tmp
LOG=_claude_tmp/verify.log
: > "$LOG"
step() { printf "\n===== %s =====\n" "$1" | tee -a "$LOG"; shift; ( "$@" ) >> "$LOG" 2>&1; code=$?; echo "exit=$code" | tee -a "$LOG"; }

step "flutter --version" flutter --version
step "app: pub get" flutter pub get
step "app: analyze" flutter analyze
step "app: test" flutter test
step "admin: pub get" sh -c "cd skilllink_admin && flutter pub get"
step "admin: analyze" sh -c "cd skilllink_admin && flutter analyze"
step "admin: test" sh -c "cd skilllink_admin && flutter test"
step "functions: npm ci" sh -c "cd functions && npm ci"
step "functions: lint" sh -c "cd functions && npm run lint"
step "functions: test" sh -c "cd functions && npm test"
# firebase-tools needs Java 21+ for the emulators. Prefer an installed JDK 21
# (Homebrew openjdk@21 or Temurin) for these steps only.
if [ -x /usr/libexec/java_home ] && /usr/libexec/java_home -v 21+ >/dev/null 2>&1; then
  RULES_JAVA_HOME=$(/usr/libexec/java_home -v 21+)
elif [ -d /opt/homebrew/opt/openjdk@21 ]; then
  RULES_JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
elif [ -d /usr/local/opt/openjdk@21 ]; then
  RULES_JAVA_HOME=/usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
fi
step "java version (default)" java -version
if [ -n "$RULES_JAVA_HOME" ]; then
  step "java version (rules tests)" "$RULES_JAVA_HOME/bin/java" -version
  export JAVA_HOME="$RULES_JAVA_HOME"
  export PATH="$RULES_JAVA_HOME/bin:$PATH"
else
  echo "No JDK 21 found: emulator tests will fail. Install: brew install openjdk@21" | tee -a "$LOG"
fi
if command -v firebase >/dev/null 2>&1; then
  step "firestore rules tests" sh firestore-tests/run.sh
  step "storage rules deps" sh -c "cd firestore-tests && npm install"
  step "storage rules tests" sh firestore-tests/run_storage.sh
else
  echo "firebase CLI not found: skipped rules tests" | tee -a "$LOG"
fi
unset JAVA_HOME
step "android: debug build" flutter build apk --debug
printf "\nDone. Full log: %s\n" "$LOG"
grep -E "^=====|^exit=" "$LOG"
