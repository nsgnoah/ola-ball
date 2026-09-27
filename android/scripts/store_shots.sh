#!/bin/zsh
# Plays a full pass-and-play match on the Android emulator and saves Play Store screenshots.
#
#   ./scripts/store_shots.sh              # Pixel 8 AVD "spinola_phone" (1080x2400) -> build/shots-store/phone
#   ./scripts/store_shots.sh <avd-name>   # any AVD you have created
#
# Captures the same screens as the iOS set: home, hand-off, wheel, round intro, question, answered,
# round reveal, match over, privacy. Requires the SDK and JDK described in android/README.md.
set -e
cd "$(dirname "$0")/.."

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

AVD="${1:-spinola_phone}"
OUT="$PWD/build/shots-store/${1:-phone}"
PKG="co.nsgsolutions.spinola"

# One emulator at a time: each booted device holds memory, and on a full disk macOS answers with swap.
if ! adb devices | grep -q "emulator-.*device"; then
  echo "Booting $AVD (headless)…"
  emulator -avd "$AVD" -no-window -no-audio -no-boot-anim -no-snapshot-save -gpu swiftshader_indirect >/dev/null 2>&1 &
  adb wait-for-device
  until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done
  BOOTED_HERE=1
fi
# A clean, consistent status bar for store shots (demo mode is built into Android).
adb shell settings put global sysui_demo_allowed 1 >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941 >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null

rm -rf "$OUT"; mkdir -p "$OUT"
adb shell rm -rf "/sdcard/Android/data/$PKG/files/shots" 2>/dev/null || true

# pipefail matters: without it the grep's exit status hides a failed test.
set -o pipefail
# leaveApksInstalledAfterRun: Gradle otherwise uninstalls the app when the tests finish, which
# deletes the app's files directory and the screenshots with it.
./gradlew :app:connectedDebugAndroidTest --console=plain \
  -Pandroid.injected.androidTest.leaveApksInstalledAfterRun=true \
  -Pandroid.testInstrumentationRunnerArguments.class="$PKG.PlayThroughTest" 2>&1 \
  | grep -E "error:|FAILED|PASSED|Tests |BUILD" \
  || { echo; echo "The play-through failed, so there are no screenshots to upload."; exit 1; }
set +o pipefail

adb pull "/sdcard/Android/data/$PKG/files/shots/." "$OUT" >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null

if [ -n "$BOOTED_HERE" ]; then adb emu kill >/dev/null 2>&1 || true; fi

echo
echo "$OUT"
ls -1 "$OUT"
sips -g pixelWidth -g pixelHeight "$OUT/02-home.png" 2>/dev/null | tail -2
