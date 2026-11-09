# Clash Timers for iOS

[![Latest iOS release](https://img.shields.io/github/v/release/Julianyin1234567890/clash-timers-ios)](https://github.com/Julianyin1234567890/clash-timers-ios/releases/latest)
![iOS 17.0+](https://img.shields.io/badge/iOS-17.0%2B-222222?logo=apple&logoColor=white)
[![Code license: MIT](https://img.shields.io/badge/code-MIT-blue)](LICENSE)

**An unofficial iPhone and iPad port of [Clash Timers by Kuswaa (Kuswa Tul Kaabah)](https://github.com/Kuswaa/clash-timers).** Credit for the original Android app, widget design and timer logic belongs to the original author. This repository maintains the iOS adaptation independently; it is not an official release from Kuswaa or Supercell.

Track your home-village builders, laboratory research and pets from an iPhone Home Screen widget. The app uses SwiftUI and WidgetKit, reuses the original project's game assets and font under their respective terms, and calculates timers offline from the village export you copy in Clash of Clans.

## Download and install

**Current release: [v1.0.4 — Copy then Sync](https://github.com/Julianyin1234567890/clash-timers-ios/releases/tag/ios-v1.0.4).** Download **ClashTimers-AltStore.ipa** from the release assets.

- [Detailed Word installation guide](https://github.com/Julianyin1234567890/clash-timers-ios/releases/latest/download/Clash-Timers-AltStore-Guide.docx)
- [Detailed PDF installation guide](https://github.com/Julianyin1234567890/clash-timers-ios/releases/latest/download/Clash-Timers-AltStore-Guide.pdf)
- [Installation and build instructions](ios/README.md)

Requires **iOS/iPadOS 17 or newer**. Install through **AltStore Classic** and choose **Keep App Extensions** to include the widget. Windows users can install with AltServer; a Mac is not required for this route. With a free Apple account, renew the app through AltStore before its seven-day signature expires. This app is not distributed through the App Store.

## What it looks like

<p align="center">
  <img src="docs/screenshots/ios-widget-large.png" alt="Large iOS widget with the original brown panel, green upgrade rows and gold Sync button" width="380">
  <img src="docs/screenshots/ios-app.png" alt="iPhone app showing a successful clipboard Sync" width="200">
</p>

Actual simulator captures with example village data. Small and medium widgets show fewer rows to fit Apple's widget sizes.

## Copy in Clash, then Sync

1. In Clash of Clans, open **Settings → More Settings → Data Export → Copy**.
2. Tap **Sync** on the medium or large widget. On the small widget, tap anywhere. You can also tap Sync inside the app.
3. Clash Timers opens and saves the copied village immediately. Choose **Allow Paste** if iOS asks, then swipe Home to return to the widget.

There is no separate Paste or Import confirmation on this path. Saved countdowns keep running between syncs. **Copy fresh data after starting new upgrades or changing their finish times in the game.** This is an offline snapshot tracker; it does not sign into Supercell ID or automatically fetch later game changes.

## Features and practical limits

- Small, medium and large Home Screen widgets for builder, laboratory and pet timers.
- Potion and Builder Bite logging, undo controls, and helper links. **Log** records an item you used in Clash; it does not show your owned inventory.
- Local finish notifications. Tapping a notification opens Clash Timers.
- Saved village data on your device, with no account, ads, analytics or network requests for timer syncing. Clipboard reads happen only after a Sync or paste action.
- Helper predictions assume you activate future helper sessions. A fresh export corrects the saved snapshot.
- iOS controls widget redraw timing. Sync opens the app; it does not silently close back to the Home Screen as the original Android activity does.

The v1.0.4 Mac build passed **25 core tests and eight simulator checks**, covering clipboard sync, widget URL launches, persistence, invalid/stale data, boost controls and widget renders. Physical-device signing and widget behavior can vary. [Build and test results](https://github.com/Julianyin1234567890/clash-timers-ios/actions/runs/42519290076).

## Original project and credits

- **Original author:** [Kuswaa / Kuswa Tul Kaabah](https://github.com/Kuswaa). [Original Clash Timers repository](https://github.com/Kuswaa/clash-timers).
- **Android version:** get its releases and updates from the original repository. The [Android documentation](docs/ANDROID.md) is retained here for reference.
- **Game artwork, names and data:** Supercell, with data/assets sourced by the original project from [clash-of-clans-data](https://github.com/chiefpansancolt/clash-of-clans-data), credited to Christopher Pezza.
- **Font:** Lilita One by Juan Montoreano, under the SIL Open Font License.

The original copyright and [MIT code license](LICENSE) are retained. Game assets and the font have separate terms; see [NOTICE](NOTICE) and the [iOS resource notices](ios/Sources/ClashTimersCore/Resources/NOTICE). The iOS port was developed with AI assistance.

For iOS bugs or contributions, [open an issue in this repository](https://github.com/Julianyin1234567890/clash-timers-ios/issues). Include your iOS version, app version and steps to reproduce the problem.

## Disclaimer

This material is unofficial and is not endorsed by Supercell. For more information see [Supercell's Fan Content Policy](https://supercell.com/en/fan-content-policy/). Clash of Clans names, artwork and game assets belong to Supercell.
