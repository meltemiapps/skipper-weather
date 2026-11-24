# Claude Code prompt: build, test and ship Skipper Weather Study Guide to TestFlight

Paste everything below the line into Claude Code on the Mac mini, started in your home folder. Run it in auto mode.

---

You are shipping the iOS/iPadOS app **Skipper Weather Study Guide** (home-screen name "Skipper Weather") to TestFlight. Work autonomously to the end. Do not stop to ask me questions unless a step below says so. Do not touch any other project folder except `skipper-weather`; you may READ (never modify) `~/Developer/aeolet` only to discover existing App Store Connect settings.

## 0. Place the project
1. Unzip `~/Downloads/skipper-weather-v1.0.zip` into `/Users/vangelis/Developer` (creates `/Users/vangelis/Developer/skipper-weather`). If that path is not writable (it may be a link to an unmounted SSD), use `/Users/vangelis/Projects` instead and say so at the end.
2. `cd` into `skipper-weather` and run `chmod +x scripts/*.sh tools/*.py`.
3. Confirm the README title reads "Skipper Weather Study Guide (unofficial)". If it still says "Skipper Weather — Unofficial Study Guide", apply the rename: README title, README release step name, PRIVACY.md and docs/*.html heading → "Skipper Weather Study Guide (unofficial)", docs/app-store-metadata.md Name → "Skipper Weather Study Guide". Commit.
4. Read `CLAUDE.md` and follow its rules (project.yml is the project source; strings come from tools/strings.py; no RYA/course names outside the disclaimer).

## 1. Credentials (discover, don't ask)
- API key: the `.p8` in `~/Keys` (`AuthKey_<KEYID>.p8`). KEYID comes from the filename. If there are several, prefer the one referenced by the `aeolet` project.
- Issuer ID and Team ID: search read-only in `~/Developer/aeolet` (if present) (fastlane/Appfile, .env*, scripts, workflow files, xcconfig, project.pbxproj `DEVELOPMENT_TEAM`), then `defaults read com.apple.dt.Xcode`, then `security find-identity -v -p codesigning` (team ID in the certificate name).
- Only if the Issuer ID genuinely cannot be found anywhere: stop and ask me for it in one line.
- Export `ASC_KEY_ID`, `ASC_ISSUER_ID`, `DEVELOPMENT_TEAM` for later steps. Never print the key contents.

## 2. Build and test until green
1. `scripts/bootstrap.sh` (installs XcodeGen via Homebrew if missing, regenerates strings and the Xcode project).
2. `scripts/test.sh` runs the SkipperCore package tests and the app tests on one iPhone and one iPad simulator.
3. The SwiftUI layer has never been compiled. Fix every compiler error and warning-as-error with minimal, correct changes, keeping the design (iOS 26 Liquid Glass, `.sidebarAdaptable` tab view, in-app language override via `model.strings`). Re-run until both simulators pass. Do not delete or weaken tests to get green.
4. Launch the app in the iPhone and iPad simulators, take screenshots of Learn, a lesson with a diagram, Quiz, Beaufort tool, Settings and About in English, Greek and Arabic. Check visually: no clipped text, Arabic is right to left, diagrams render, glass surfaces are legible. Fix what you find. Save the screenshots to `build/screenshots/`.
5. Commit each fix with a clear message.

## 3. App Store Connect
1. Using the API key (JWT, ES256, aud `appstoreconnect-v1`), confirm the bundle ID `com.meltemiapps.skipperweather` exists; create it (platform IOS, name "Skipper Weather Study Guide") if missing.
2. Find the app record for that bundle ID (`GET /v1/apps?filter[bundleId]=...`). The record is being created separately in the browser; if it does not exist yet, poll every 2 minutes for up to 60 minutes, carrying on with step 2 work meanwhile. If it still does not exist after 60 minutes, stop and tell me only that.
3. Verify availability excludes China mainland (territory `CHN`) and includes every other territory. If it doesn't, set it through the App Availability v2 API (`/v2/appAvailabilities`), with `availableInNewTerritories` true and CHN unavailable.

## 4. Ship to TestFlight
1. `scripts/ship-testflight.sh` (archives Release with a timestamp build number and uploads using the API key). It runs bootstrap and tests again first.
2. Poll the build (`GET /v1/builds?filter[app]=<id>&sort=-uploadedDate`) until `processingState` is `VALID` (up to 45 minutes).
3. Make sure an internal TestFlight group named "Internal" exists for the app and that the Account Holder (my Apple ID) is a tester in it, so the build appears in the TestFlight app on my iPhone and iPad. Export compliance is already declared (`ITSAppUsesNonExemptEncryption` = NO).

## 5. Finish
- `git tag v1.0.0-build<N>`.
- Update `docs/app-store-metadata.md` if anything changed.
- Reply to me with exactly: the build number, the TestFlight status, a one-paragraph list of fixes you made, and the path to the screenshots. Nothing else.
