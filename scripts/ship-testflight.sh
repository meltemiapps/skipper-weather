#!/usr/bin/env bash
# Archives a Release build and uploads it to TestFlight with an App Store Connect API key.
#
# Required environment (same key the Aeolet pipeline uses is fine):
#   ASC_KEY_ID        App Store Connect API key ID
#   ASC_ISSUER_ID     API key issuer ID
#   DEVELOPMENT_TEAM  Apple Developer team ID
# Optional:
#   ASC_KEY_PATH      defaults to ~/Keys/AuthKey_${ASC_KEY_ID}.p8
#   BUILD_NUMBER      defaults to a UTC timestamp (always increasing)
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ASC_KEY_ID:?set ASC_KEY_ID}"; : "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"; : "${DEVELOPMENT_TEAM:?set DEVELOPMENT_TEAM}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/Keys/AuthKey_${ASC_KEY_ID}.p8}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%Y%m%d%H%M)}"
[ -f "$ASC_KEY_PATH" ] || { echo "API key not found at $ASC_KEY_PATH"; exit 1; }

export DEVELOPMENT_TEAM
scripts/bootstrap.sh
scripts/test.sh

AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
mkdir -p build
sed "s/__TEAM_ID__/$DEVELOPMENT_TEAM/" ExportOptions.plist > build/ExportOptions.plist

xcodebuild archive -project SkipperWeather.xcodeproj -scheme SkipperWeather -configuration Release \
  -destination "generic/platform=iOS" -archivePath build/SkipperWeather.xcarchive \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" "${AUTH[@]}" -quiet

xcodebuild -exportArchive -archivePath build/SkipperWeather.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist -exportPath build/export "${AUTH[@]}"

echo "Uploaded build $BUILD_NUMBER. It appears in TestFlight after Apple's processing (usually 5-30 minutes)."
