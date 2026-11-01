#!/bin/bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PROJECT="BilouNook/BilouNook.xcodeproj"
SCHEME="BilouNook"
LOG_DIR="$ROOT/build/logs"
BUILD_LOG="$LOG_DIR/smoke-build.log"
TEST_LOG="$LOG_DIR/smoke-test.log"
mkdir -p "$LOG_DIR"

python3 scripts/check-project.py
CHECK_RESULT=$?
if [ "$CHECK_RESULT" -eq 0 ]; then
    echo "PROJECT PASS"
else
    echo "PROJECT FAIL"
fi

python3 scripts/check-tests.py
TEST_QUALITY_RESULT=$?
if [ "$TEST_QUALITY_RESULT" -eq 0 ]; then
    echo "TEST QUALITY PASS"
else
    echo "TEST QUALITY FAIL"
fi

xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug -derivedDataPath ./build build > "$BUILD_LOG" 2>&1
BUILD_RESULT=$?
if [ "$BUILD_RESULT" -eq 0 ]; then
    echo "BUILD PASS"
else
    echo "BUILD FAIL"
fi

xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug -derivedDataPath ./build -destination 'platform=macOS' test > "$TEST_LOG" 2>&1
TEST_RESULT=$?
if [ "$TEST_RESULT" -eq 0 ]; then
    echo "TESTS PASS"
else
    echo "TESTS FAIL"
fi

echo "Logs: $BUILD_LOG $TEST_LOG"
exit $(( CHECK_RESULT != 0 || TEST_QUALITY_RESULT != 0 || BUILD_RESULT != 0 || TEST_RESULT != 0 ))
