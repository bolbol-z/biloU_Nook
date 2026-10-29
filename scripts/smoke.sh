#!/bin/bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PROJECT="BilouNook/BilouNook.xcodeproj"
SCHEME="BilouNook"
BUILD_LOG="/tmp/bilounook_smoke_build.log"
TEST_LOG="/tmp/bilounook_smoke_test.log"

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
exit $(( BUILD_RESULT != 0 || TEST_RESULT != 0 ))
