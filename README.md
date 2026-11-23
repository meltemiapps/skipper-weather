# Skipper Weather Study Guide (unofficial)

An open-source iPhone and iPad app for learning marine weather at skipper level: pressure and wind, fronts, clouds, fog, sea breezes, Beaufort and sea state, forecast terminology and weather for passage planning.

> **Unofficial.** This app is not affiliated with, endorsed by, sponsored by or associated with the Royal Yachting Association (RYA) or any other sailing organisation, training centre, examining body or meteorological service. The author is not a certified instructor.
>
> **Not for navigation.** For learning only. Always use official forecasts and seek qualified instruction.

## Features
- 8 modules, 16 lessons, 40 quiz questions with explanations (original content)
- Tools: Beaufort scale, barometric tendency, unit converter
- 16 interface languages: English, Greek, Spanish, Italian, French, Portuguese, German, Dutch, Polish, Russian, Serbian (Cyrillic), Danish, Swedish, Norwegian Bokmål, Finnish and Arabic (right-to-left)
- Units: °C/°F · hPa/mb/inHg · kn/Beaufort/km/h/m/s/mph · nm/km/mi · m/ft
- iOS/iPadOS 26 Liquid Glass design; sidebar on iPad
- No account, no tracking, no analytics, no network access

## Build
Requirements: macOS with Xcode 26+, Homebrew.

```sh
scripts/bootstrap.sh     # installs XcodeGen, generates strings + SkipperWeather.xcodeproj
scripts/test.sh          # core tests + app tests on iPhone and iPad simulators
open SkipperWeather.xcodeproj
```

The core logic (`Packages/SkipperCore`: units, Beaufort, tendency, content validation, quiz engine) also builds and tests on Linux with `swift test`.

## Ship to TestFlight
```sh
export ASC_KEY_ID=… ASC_ISSUER_ID=… DEVELOPMENT_TEAM=…
scripts/ship-testflight.sh
```
Or push a `v*` tag to run `.github/workflows/testflight.yml` on a self-hosted macOS runner.

### Before first release
1. Create the app record in App Store Connect (bundle ID `com.meltemiapps.skipperweather`, name “Skipper Weather Study Guide”; home-screen name stays “Skipper Weather”).
2. Update `AppLinks` in `SkipperWeather/App/AppModel.swift` if the repository or GitHub Pages URL differs.
3. Enable GitHub Pages from `/docs` so the privacy policy is live at the URL in `AppLinks.privacyPolicy`.

## Project layout
| Path | Purpose |
|---|---|
| `SkipperWeather/` | SwiftUI app (views, diagrams, resources) |
| `SkipperWeather/Resources/Content/content.<lang>.json` | Lesson and quiz content per language |
| `tools/strings.py` | Source of truth for interface strings in all languages |
| `tools/build_strings.py` | Validates translations and generates `Localizable.xcstrings` |
| `Packages/SkipperCore/` | Platform-independent logic with unit tests |
| `docs/` | Privacy policy web page (GitHub Pages) |

## Contributing translations
See [CONTRIBUTING.md](CONTRIBUTING.md). Native-speaker review of lesson content is especially welcome.

## Licence
MIT — see [LICENSE](LICENSE). Content, diagrams and the app icon are original works by the author.
