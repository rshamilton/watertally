# Water Tally

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

Simple, private water tracking for iPhone and iPad. One-tap logging, Home Screen and Lock Screen widgets, trends and streaks, optional Apple Health, optional reminders. No account, no ads, no analytics, no servers.

Water Tally is open source under the GNU GPL v3. The full app, its widgets and its website live in this repository.

- App Store: <https://apps.apple.com/us/app/water-tally-drink-tracker/id6814481718>
- Website: <https://rshamilton.github.io/watertally/>
- Support: [watertally@googlegroups.com](mailto:watertally@googlegroups.com) or [open an issue](https://github.com/rshamilton/watertally/issues)

> Water Tally is a personal tracking tool, not a medical device. See `web/medical-disclaimer.html`.

## Features

- **One-tap logging** with your own buttons (up to 12), a custom-amount button, undo, and logging for past days
- **Progress ring**, goal caption, streaks, celebration when you reach your goal
- **History, calendar, trends** (week / month / 3 months / year), weekly summary on Sundays
- **Widgets**: small, medium, large (tap to log without opening the app) plus Lock Screen circular / rectangular / inline
- **Apple Health (optional)**: writes each entry as a Water sample tagged with the entry's UUID, so edits and deletes are exact; a non-destructive "Restore" merges missing entries back in
- **Reminders (optional)**: local notifications in a window you choose; they stop for the day once the goal is met
- **Units**: ounces or millilitres everywhere (app, widgets, charts, export)
- **Export** to CSV/JSON, **Delete all data** (optionally including what Water Tally wrote to Health)
- **Legal**: first-run acknowledgment (Terms, Privacy, Medical Disclaimer) with re-prompt when `AppInfo.currentLegalVersion` is bumped

## Project layout

| Path | What it is |
|---|---|
| `WaterTally/` | The app target (SwiftUI). `AppState.swift` is the single source of truth. |
| `WaterTallyWidgets/` | The widget extension (`WaterTallyWidget.swift`, quick-log App Intent). |
| `Shared/SharedModels.swift` | Models, limits, unit maths, streaks, and storage. Compiled into **both** targets so the app and widget can never disagree about the on-disk format. |
| `web/` | Static website for GitHub Pages: landing page, privacy policy, terms, medical disclaimer, support. |
| `docs/` | App Store listing copy. |
| `tools/` | Asset generator, web builder, logic tests. |
| `scripts/run-ios-sim.sh` | Build, install and launch on a simulator. |

## Build & run

Requires Xcode 26+ (iOS 17+ deployment target).

```bash
scripts/run-ios-sim.sh                 # build + launch on a simulator
DEVICE_NAME="iPhone 17 Pro" scripts/run-ios-sim.sh
```

HealthKit and App Group behaviour needs a signed build on a real device; unsigned simulator builds log "Missing com.apple.developer.healthkit entitlement" and Health stays disabled.

### Running on your own device

The project is set up for the official App Store build. To sign it with your own Apple Developer account:

1. In Xcode, select each target (`WaterTally`, `WaterTallyWidgetsExtension`) and set **Signing & Capabilities > Team** to your team.
2. Change the bundle identifiers to ones you own, for example `com.example.WaterTally` and `com.example.WaterTally.Widgets`.
3. Change the App Group (`group.me.ryham.WaterTally`) to your own, in **both** `.entitlements` files and in `Shared/SharedModels.swift`, so the app and widget can share data.

Please don't commit those signing changes in pull requests.

### Debug launch arguments (DEBUG builds only)

`WaterTally/DebugLaunch.swift` lets you jump to a screen with sample data, handy for screenshots:

```bash
scripts/run-ios-sim.sh -demoData -showScreen trends
```

Screens: `main edit settings trends history calendar weekly consent onboarding yesterday celebrate`.
Flags: `-demoData -metric -freshInstall -simulateLog <ounces> -onboardingPage <0-5> -daysAgo <n>`.

`tools/app-store-screenshots.sh` regenerates the App Store screenshots (6.5" iPhone and 13" iPad) into `screenshots/`.

## Tools

```bash
tools/run-tests.sh                          # logic tests for Shared/SharedModels.swift
swift tools/generate_brand_assets.swift     # app icon (light/dark/tinted), launch logo, web images
python3 tools/build_web.py                  # regenerate web/*.html (name, email, dates live at the top)
```

## Publishing the website

`web/` is plain static HTML/CSS with relative links, served by GitHub Pages at <https://rshamilton.github.io/watertally/> from the `gh-pages` branch of this repository. After editing `tools/build_web.py` and regenerating, publish with:

```bash
git subtree push --prefix web origin gh-pages
```

The in-app links (`AppLinks` in `WaterTally/LegalViews.swift`) point at that address.

## Privacy design

- All data lives in the App Group `UserDefaults` container on the device. The app makes **no network requests**.
- Privacy manifests (`PrivacyInfo.xcprivacy`, app and widget) declare no tracking and no collected data.
- Apple Health access is limited to the Water type and is fully optional.

## Contributing

Bug reports, ideas and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Copyright (C) 2026 Ryan Hamilton.

The source code is licensed under the [GNU General Public License v3.0](LICENSE). You may use, study, change and share it, provided that anything you distribute based on it is also released under the GPL v3 with its source.

The name "Water Tally" and the app icon are not covered by the license. If you ship your own build, please give it a different name and icon so people don't confuse it with the official app.

Apple, Apple Health, iPhone, iPad and App Store are trademarks of Apple Inc. Water Tally is not affiliated with Apple.
