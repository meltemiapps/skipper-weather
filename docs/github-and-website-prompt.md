Do all of the following without asking me anything unless a sign-in is required. Leave every other project alone. British English.

PART A - Skipper Weather source to GitHub
1. cd ~/Projects/skipper-weather
2. Scan the repo and its git history for secrets (API keys, .p8, .p12, passwords, tokens, team-private files). If any are found, stop and report them; do not push.
3. git add -A and commit: "Diagram corrections, website URLs, meteorology review pack".
4. If github.com/meltemiapps/skipper-weather does not exist, create it as a PUBLIC repo with: gh repo create meltemiapps/skipper-weather --public --source=. --remote=origin --description "Unofficial, open-source weather study guide for skippers. iPhone and iPad. Not affiliated with the RYA or any other organisation."
   If gh is not signed in, run gh auth login and tell me only that I need to sign in.
5. git push -u origin main --tags
6. Set the repo homepage to https://meltemiapps.co.uk/skipper-weather/support/ and topics: ios, swiftui, sailing, weather, meteorology, study-guide, open-source.

PART B - Website (meltemiapps-site)
7. Find the site repo: /Volumes/P310-01/Developer/meltemiapps-site. If the SSD is not mounted, stop and tell me "Connect the P310 SSD".
8. git pull. Confirm skipper-weather/privacy/index.html and skipper-weather/support/index.html exist.
9. In index.html add a Skipper Weather card in the apps section. Copy the structure, classes and styling of the Diesel Ready card exactly. Place it directly after Diesel Ready.
   - Title: Skipper Weather Study Guide
   - Description: Unofficial, open-source study guide to marine weather for skippers, for iPhone and iPad.
   - Features (3 short bullets, same style as other cards): 27 lessons with diagrams for every topic; Exam-style questions and a timed mock exam; 16 languages and your choice of units
   - Store status: a "Coming soon" badge for the App Store. Use the same markup as the Converto / Προσευχητάριο "Coming soon" status. No App Store link.
   - Links: Privacy policy -> /skipper-weather/privacy/, Support -> /skipper-weather/support/, Source code -> https://github.com/meltemiapps/skipper-weather
   - Icon: copy the app icon from ~/Projects/skipper-weather/SkipperWeather/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png to skipper-weather/icon.png, resized to the same pixel size the other card icons use. Reference it like the other cards.
10. Open index.html locally and check the card renders like the others on desktop and mobile widths.
11. git add -A, commit "Add Skipper Weather Study Guide: coming soon card, privacy and support pages", git push.
12. npx wrangler@4 deploy --message "Skipper Weather coming soon"
13. Verify with curl that these return 200 and contain "Skipper Weather": https://meltemiapps.co.uk/ , https://meltemiapps.co.uk/skipper-weather/privacy/ , https://meltemiapps.co.uk/skipper-weather/support/

Finish by printing exactly three lines:
GITHUB <repo URL> <latest commit hash>
SITE <deployed version id>
CHECK <the three HTTP status codes>
