Build 3 of Skipper Weather Study Guide. Work autonomously to the end. Do not ask questions. Only touch ~/Projects/skipper-weather, /tmp, and (step 6) /Volumes/P310-01/Developer/meltemiapps-site. British English.

Already done in the working tree (uncommitted, do NOT rewrite): six diagram fixes in DiagramView.swift, website URLs in AppModel.swift, review corrections and three new lessons (sea.reading, forecasts.reconcile, planning.gonogo), one new lesson section (sea.tide), 8 new questions including two passage scenarios, one glossary term, in content-src/en, el and es. DiagramWalkTests already lists the new lessons. docs/review-response-2026-11-25.md explains the changes.

1. cd ~/Projects/skipper-weather. Run python3 tools/build_content.py: it must print OK with 30 lessons and 88 questions for en, el and es. Commit as "Build 3 content: review corrections, wave forecasts, forecast reconciliation, go/no-go, passage scenarios".
2. scripts/bootstrap.sh then scripts/test.sh. Core and app tests must pass on one iPhone and one iPad simulator. If any test hard-codes 27 lessons or 80 questions, update it to the new counts. Fix compile errors minimally; never weaken tests.
3. Visual check with the SkipperWeatherScreenshots scheme, DiagramWalkTests (testWalkLessons and testWalkQuiz), on the smallest iPhone simulator, WALK_LANGS=en,el,es, standard size and again with the largest accessibility size. SCREENSHOT_DIR=~/Projects/skipper-weather/build/screenshots/build3. Look at every diagram PNG yourself, especially: warm front and occlusion symbols on the side of movement; Buys Ballot (wind from the south, low on the observer's left); coastal convergence; Sirocco from the south-east; cold-front slope with cold air undercutting; warm-front section with no overlapping label. Fix any label overlap or clipping in DiagramView.swift and re-run until clean. Keep the final PNGs.
4. Ship exactly as Build 2: archive with xcodebuild -allowProvisioningUpdates DEVELOPMENT_TEAM=6Q7HCLY6C6, CURRENT_PROJECT_VERSION = UTC timestamp yyyyMMddHHmm, MARKETING_VERSION 1.0.0, upload with xcodebuild -exportArchive and ExportOptions.plist using the Apple account signed in to Xcode. Exclude nothing else; China mainland exclusion is already set in App Store Connect.
5. Commit everything (screenshots excluded by .gitignore under build/), tag build3-<build number>, git push origin main --tags.
6. Website: if /Volumes/P310-01/Developer/meltemiapps-site exists, in index.html change the Skipper Weather card text "27 lessons" to "30 lessons" (whatever the exact wording), commit, git push, npx wrangler@4 deploy --message "Skipper Weather 30 lessons". If the SSD is not mounted, skip this step and say so.
7. Copy build/screenshots/build3 to ~/Downloads/skipper-weather-build3-screenshots/ (flat folder of PNGs).

Finish by printing exactly:
BUILD <build number> UPLOADED
CONTENT <the three OK lines>
SCREENSHOTS <number of PNGs copied>
SITE <deployed or skipped>
