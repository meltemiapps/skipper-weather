Build 4 of Skipper Weather Study Guide. Work autonomously to the end. Do not ask questions. Only touch ~/Projects/skipper-weather and /tmp. British English.

Already done in the working tree (uncommitted, do NOT rewrite): content corrections from the second review and three new passage scenarios (q.pl.12 Hamble–Poole, q.pl.13 Chania–Piraeus, q.pl.14 Chania–Kythira) in content-src/en, el and es; docs/review-response-2026-11-25.md. No Swift or diagram changes are needed.

1. cd ~/Projects/skipper-weather. python3 tools/build_content.py must print OK with 30 lessons and 91 questions for en, el and es. Commit as "Build 4 content: second review corrections, Portland and Kythnos redesign, Hamble–Poole, Chania–Piraeus, Chania–Kythira".
2. scripts/test.sh: core and app tests must pass on one iPhone and one iPad simulator. Fix minimally; never weaken tests.
3. Quick visual check only (diagrams are unchanged): on the smallest iPhone simulator at standard text size, open Quiz > Planning in English, Greek and Spanish, step through q.pl.12, q.pl.13 and q.pl.14 to the end, and confirm no text is clipped. Do not run the full DiagramWalkTests.
4. Ship exactly as Build 3: archive with xcodebuild -allowProvisioningUpdates DEVELOPMENT_TEAM=6Q7HCLY6C6, CURRENT_PROJECT_VERSION = UTC timestamp yyyyMMddHHmm, MARKETING_VERSION 1.0.0, upload with xcodebuild -exportArchive and ExportOptions.plist using the Apple account signed in to Xcode.
5. Commit, tag build4-<build number>, git push origin main --tags.

Finish by printing exactly:
BUILD <build number> UPLOADED
CONTENT <the three OK lines>
