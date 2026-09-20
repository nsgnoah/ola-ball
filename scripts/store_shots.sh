#!/bin/zsh
# Plays a full pass-and-play match on an iPhone 16 Pro Max simulator and saves 6.9" App Store screenshots
# (1320x2868) to build/shots-store. Pass a different simulator UDID as $1 to shoot another size.
set -e
cd "$(dirname "$0")/.."
DEVICE="${1:-CBDD9DAB-012D-47BD-8103-4963D2E8AFD6}"   # iPhone 16 Pro Max
OUT="$PWD/build/shots-store"
mkdir -p "$OUT"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
for i in {1..60}; do xcrun simctl list devices | grep "$DEVICE" | grep -q Booted && break; sleep 2; done   # bootstatus -b can hang
xcodebuild test -project OlaBall.xcodeproj -scheme OlaBall \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  -derivedDataPath build/DerivedData \
  -only-testing:OlaBallUITests/PlayThroughUITests/testPassAndPlayMatch \
  TEST_RUNNER_OLABALL_SHOTS="$OUT" 2>&1 | grep -E "error:|Test Case .* (passed|failed)|TEST (SUCCEEDED|FAILED)"
ls -1 "$OUT"
