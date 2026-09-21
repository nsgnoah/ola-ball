#!/bin/zsh
# Plays a full pass-and-play match and saves App Store screenshots.
#
#   ./scripts/store_shots.sh            # 6.9" iPhone  (1320x2868) -> build/shots-store/iphone
#   ./scripts/store_shots.sh ipad       # 13" iPad     (2064x2752) -> build/shots-store/ipad
#   ./scripts/store_shots.sh <udid>     # any simulator you name
#
# Captures: home, hand-off, wheel, round intro, question, answered, round reveal, match over.
set -e
cd "$(dirname "$0")/.."

case "${1:-iphone}" in
  iphone) DEVICE_NAME="iPhone 16 Pro Max"; OUT="iphone" ;;
  ipad)   DEVICE_NAME="iPad Pro 13-inch (M4)"; OUT="ipad" ;;
  *)      DEVICE_NAME=""; DEVICE="$1"; OUT="custom" ;;
esac

if [ -n "$DEVICE_NAME" ]; then
  DEVICE=$(xcrun simctl list devices available | grep -F "$DEVICE_NAME (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  [ -n "$DEVICE" ] || { echo "No simulator named '$DEVICE_NAME'. Create one in Xcode > Devices."; exit 1; }
fi

DIR="$PWD/build/shots-store/$OUT"
rm -rf "$DIR"; mkdir -p "$DIR"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
# A clean, consistent status bar for store shots.
xcrun simctl status_bar "$DEVICE" override --time "9:41" --cellularBars 4 --batteryState charged --batteryLevel 100 2>/dev/null || true

rm -rf build/shots

xcodebuild test -project OlaBall.xcodeproj -scheme OlaBall \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  -derivedDataPath build/DerivedDataShots \
  -only-testing:OlaBallUITests/PlayThroughUITests/testPassAndPlayMatch 2>&1 \
  | grep -E "error:|Test Case .* (passed|failed)|TEST (SUCCEEDED|FAILED)"

# The test writes to build/shots (xcodebuild does not reliably pass TEST_RUNNER_* through to the
# runner, so the test falls back to a path beside its own source). Collect them here.
mv build/shots/*.png "$DIR"/ 2>/dev/null || true
rm -rf build/shots

# Booted simulators hold memory, and on a full disk macOS answers that with swap. Let it go.
xcrun simctl shutdown "$DEVICE" 2>/dev/null || true

echo
echo "$DIR"
ls -1 "$DIR"
sips -g pixelWidth -g pixelHeight "$DIR/02-home.png" 2>/dev/null | tail -2
