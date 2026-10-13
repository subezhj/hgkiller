#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/HGUIKitRegression.app
SIM_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
SIM_ARCH="$(uname -m)"
xcrun --sdk iphonesimulator clang \
  -target "$SIM_ARCH-apple-ios14.0-simulator" -isysroot "$SIM_SDK" \
  -fobjc-arc -fblocks -O1 -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations \
  -I src src/HGCore.m src/HGChrome.m src/HGLayout.m src/HGTabBar.m \
  src/HGSettings.m src/HGEntry.m tests/UIKitRegression.m \
  -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics \
  -o build/HGUIKitRegression.app/HGUIKitRegression
cat > build/HGUIKitRegression.app/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.phoenix.video</string>
<key>CFBundleExecutable</key><string>HGUIKitRegression</string>
<key>CFBundleName</key><string>HGUIKitRegression</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1.3</string>
<key>MinimumOSVersion</key><string>14.0</string>
<key>UIDeviceFamily</key><array><integer>1</integer></array>
<key>UILaunchScreen</key><dict/>
</dict></plist>
PLIST
codesign --force --sign - --timestamp=none build/HGUIKitRegression.app
SIM_ID="$(xcrun simctl list devices available -j | python3 -c '
import json,sys
devices=[d for group in json.load(sys.stdin)["devices"].values() for d in group if "iPhone" in d["name"]]
if not devices: raise SystemExit("No iPhone simulator available")
print(next((d["udid"] for d in devices if d["state"]=="Booted"), devices[0]["udid"]))
')"
xcrun simctl boot "$SIM_ID" 2>/dev/null || true
xcrun simctl bootstatus "$SIM_ID" -b
xcrun simctl install "$SIM_ID" build/HGUIKitRegression.app
xcrun simctl launch "$SIM_ID" com.phoenix.video
SIM_DATA="$(xcrun simctl get_app_container "$SIM_ID" com.phoenix.video data)"
RESULT="$SIM_DATA/Documents/hg-results.json"
for tick in $(seq 1 60); do
  if [ -f "$RESULT" ]; then break; fi
  sleep 1
done
if [ ! -f "$RESULT" ]; then
  echo "UIKit regression app produced no result; possible main-thread layout loop or crash." >&2
  cp "$SIM_DATA/Documents/hg-progress.json" build/uikit-progress.json 2>/dev/null || true
  PID="$(pgrep -f '/HGUIKitRegression.app/HGUIKitRegression' | head -1 || true)"
  if [ -n "$PID" ]; then /usr/bin/sample "$PID" 1 -file build/uikit-hang-sample.txt || true; fi
  /usr/bin/log show --style compact --last 3m --predicate 'process == "HGUIKitRegression"' > build/uikit-app.log 2>&1 || true
  xcrun simctl terminate "$SIM_ID" com.phoenix.video || true
  exit 1
fi
cp "$RESULT" build/uikit-regression-results.json
xcrun simctl terminate "$SIM_ID" com.phoenix.video || true
python3 -c '
import json
r=json.load(open("build/uikit-regression-results.json"))
print(json.dumps(r, ensure_ascii=False, indent=2))
if not r["success"]: raise SystemExit("UIKit regression failed: "+r["error"])
if r["checks"] < 200: raise SystemExit("UIKit regression did not complete all phases")
'
