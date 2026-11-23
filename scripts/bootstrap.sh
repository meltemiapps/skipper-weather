#!/usr/bin/env bash
# One-time setup on the Mac: installs XcodeGen, regenerates strings and the Xcode project.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || brew install xcodegen
python3 tools/build_strings.py
: "${DEVELOPMENT_TEAM:=$(defaults read com.apple.dt.Xcode IDEProvisioningTeamManagerLastSelectedTeamID 2>/dev/null || echo "")}"
export DEVELOPMENT_TEAM
[ -n "$DEVELOPMENT_TEAM" ] || echo "warning: DEVELOPMENT_TEAM not set; set it in Xcode > Signing or export it before running."
xcodegen generate
echo "Open SkipperWeather.xcodeproj, or run scripts/test.sh"
