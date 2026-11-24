# Build 2: instructions for Claude Code on the Mac mini

You are upgrading the iOS/iPadOS app **Skipper Weather Study Guide** (bundle `com.meltemiapps.skipperweather`, team `6Q7HCLY6C6`, App Store Connect app 6838508688) from Build 1 to Build 2 and shipping it to TestFlight. Work autonomously to the end. Do not ask questions. Only touch `~/Projects/skipper-weather` (and `/tmp`).

## 0. Merge the Build 2 source into the working repo
- The Build 2 source is unpacked at `/tmp/sw-build2/skipper-weather`. The working repo is `~/Projects/skipper-weather`; its git history contains the compile fixes you made for Build 1.
- Copy Build 2 over the working repo without its `.git`: `rsync -a --exclude .git --exclude build /tmp/sw-build2/skipper-weather/ ~/Projects/skipper-weather/`.
- Run `git diff HEAD --stat`, then inspect your Build 1 fix commits (`git log`, `git show`). Re-apply any Build 1 fix that the copy overwrote and that is still needed (for example API availability or concurrency fixes). Commit as "Build 2 source".

## 1. Translate lesson content into Greek and Spanish
- Source: `content-src/en/NN-<module>.json` (10 files). Terminology: `content-src/el/_meta.json` and `content-src/es/_meta.json` (glossary and diagram labels, already written and reviewed: use these terms exactly).
- Create `content-src/el/NN-<module>.json` and `content-src/es/NN-<module>.json` with identical structure. Translate ONLY these text fields: `title`, `summary`, `heading`, `paragraphs`, `keyPoints`, `context`, `prompt`, `options`, `optionExplanations`, `explanation`. Never change `id`, `kind`, `answers`, `numeric`, `diagram`, `variant`, `symbol`, option order or array lengths.
- Quality bar: write as a native-speaking sailing instructor would, not word-for-word. Greek: standard Greek maritime and meteorological usage (e.g. δεξιόστροφη / αριστερόστροφη στροφή του ανέμου, ισοβαρείς, συνοπτικός χάρτης, λαίλαπα, μέτωπο συσφίξεως, σημείο δρόσου, μήκος ανάπτυξης, θαλάσσια αύρα, καταβατικός άνεμος, κλίμακα Μποφόρ). Spanish (Spain): standard nautical usage (rolar a la derecha / a la izquierda, isobaras, mapa sinóptico, turbonada, frente ocluido, punto de rocío, fetch, virazón, viento catabático, escala Beaufort). Keep numbers, units and bearings exactly; use the local decimal separator only in prose, never in `numeric`.
- Run `python3 tools/build_content.py`. It must print OK for en, el and es. It rejects structural drift and strings left in English. Fix and rerun until clean.
- Do not create content for other languages; they fall back to English with a notice until Build 3.

## 2. Build and test
- `scripts/bootstrap.sh`, then `scripts/test.sh`. The core package tests and the app tests must pass on one iPhone and one iPad simulator.
- The SwiftUI layer changed heavily (new `DiagramView.swift` with 27 diagrams, segment-based `LessonView`, new `QuizView.swift` with single, multi, numeric, order and scenario questions and a timed mock exam, `GlossaryView`). Fix every compiler error with minimal changes, keeping the design and keeping all text localised (diagram text comes from `diagramLabels`; UI text from `model.strings`). Do not weaken or delete tests.

## 3. Visual check (fix what you find)
- On the smallest available iPhone simulator, and again with Dynamic Type set to the largest accessibility size, open every lesson in English, Greek and Spanish and screenshot each diagram. Also screenshot one question of each kind and the mock exam start screen.
- Check: no diagram labels overlap each other or the drawing, no text clipped or truncated in cards, diagrams read clearly. Adjust label positions and font sizes in `DiagramView.swift` until clean. Save final screenshots to `build/screenshots/build2/`.

## 4. Ship
- Archive with `xcodebuild -allowProvisioningUpdates DEVELOPMENT_TEAM=6Q7HCLY6C6`, with `CURRENT_PROJECT_VERSION` set to a UTC timestamp and `MARKETING_VERSION` 1.0.0, and upload with `xcodebuild -exportArchive` and `ExportOptions.plist` (teamID 6Q7HCLY6C6, destination upload) using the Apple account signed in to Xcode, exactly as for Build 1. There is no App Store Connect API key on this Mac.
- Commit everything and tag `build2-<build number>`.

## 5. Finish
Print only: the build number, then `UPLOADED`, then one line per language with the counts of lessons and questions from `build_content.py`.
