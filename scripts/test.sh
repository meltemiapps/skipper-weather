#!/usr/bin/env bash
# Builds and runs all tests (core package + app tests) on an iPhone and an iPad simulator.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -d SkipperWeather.xcodeproj ] || scripts/bootstrap.sh
python3 tools/build_strings.py
(cd Packages/SkipperCore && swift test)
mkdir -p build
pick() { xcrun simctl list devices available | grep -E "^\s+$1" | head -1 | sed -E 's/^ +//; s/ \(.*//'; }
IPHONE="${IPHONE_SIM:-$(pick iPhone)}"; IPAD="${IPAD_SIM:-$(pick iPad)}"
for DEVICE in "$IPHONE" "$IPAD"; do
  echo "== Testing on $DEVICE"
  xcodebuild test -project SkipperWeather.xcodeproj -scheme SkipperWeather \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -quiet CODE_SIGNING_ALLOWED=NO 2>&1 | tee "build/test-${DEVICE// /_}.log" | tail -20
done
