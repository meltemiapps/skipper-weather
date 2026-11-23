# Notes for Claude Code sessions on the Mac mini

- Generated, not committed: `SkipperWeather.xcodeproj` (run `scripts/bootstrap.sh`). Edit `project.yml` instead.
- Generated from `tools/strings.py`: `Localizable.xcstrings`, `InfoPlist.xcstrings`. Never hand-edit them.
- All UI text goes through `model.strings("key")` / `model.strings.format(...)` so the in-app language override works.
- Branding rule: no RYA / Day Skipper / Coastal Skipper / Yachtmaster wording anywhere except the disclaimer strings.
- Verify with `scripts/test.sh` before `scripts/ship-testflight.sh`.
