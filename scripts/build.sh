#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
clang -std=c11 -Wall -Wextra -Werror tests/test_geometry.c -lm -o build/geometry-tests
build/geometry-tests
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun --sdk iphoneos clang \
  -target arm64-apple-ios14.0 -isysroot "$SDK" \
  -dynamiclib -fobjc-arc -fblocks -O2 -Wall -Wextra \
  -Wno-unused-parameter -Wno-deprecated-declarations \
  -I src src/HGCore.m src/HGChrome.m src/HGLayout.m src/HGTabBar.m src/HGFeedLayout.m src/HGSettings.m src/HGEntry.m \
  -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics \
  -Wl,-install_name,@rpath/hgkiller.dylib \
  -o build/hgkiller.dylib
codesign --force --sign - --timestamp=none build/hgkiller.dylib
codesign --verify --strict build/hgkiller.dylib
test "$(lipo -archs build/hgkiller.dylib)" = "arm64"
otool -L build/hgkiller.dylib
if otool -L build/hgkiller.dylib | grep -Eqi 'substrate|substitute|libhooker'; then
  echo "Unexpected hook framework dependency" >&2
  exit 1
fi
shasum -a 256 build/hgkiller.dylib > build/SHA256SUMS.txt
echo "Built build/hgkiller.dylib"
