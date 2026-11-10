# Contributing to Water Tally

Thanks for your interest. Water Tally is a small app with a narrow focus: fast, calm, private water logging. Changes that keep it simple are the most likely to be merged.

## Reporting bugs and ideas

Open an [issue](https://github.com/rshamilton/watertally/issues). For bugs, include your device, iOS version, app version (Settings > About) and the steps to reproduce.

Please don't post anything personal or health-related in public issues. For private matters, email [watertally@googlegroups.com](mailto:watertally@googlegroups.com).

## Pull requests

1. Open an issue first for anything larger than a small fix, so we can agree on the approach.
2. Keep the privacy promise: no network requests, no analytics, no third-party SDKs, no accounts.
3. Keep `Shared/SharedModels.swift` as the single definition of the on-disk format; the app and the widget both compile it.
4. Run the logic tests before you open the PR:

   ```bash
   tools/run-tests.sh
   ```

5. Check the app on a simulator (`scripts/run-ios-sim.sh`) in light and dark mode, and on an iPad size if you touched layout.
6. Don't include your own signing changes (team, bundle IDs, App Group).

## Licensing of contributions

Water Tally is licensed under the [GNU GPL v3](LICENSE). By submitting a contribution you agree that it is licensed under the GPL v3, and you also give Ryan Hamilton permission to distribute it as part of the official Water Tally app on Apple's App Store.
