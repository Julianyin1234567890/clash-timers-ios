# Clash Timers for iPhone and iPad

Requires **iOS or iPadOS 17 or newer**. This is a native SwiftUI app. It imports the same home-village export as the Android version and calculates timers offline. No Supercell login, API key, or backend is needed.

## Install from Windows

**Version 1.0.2 restores the original visual design and interactive widget controls.** The artwork and font come from the Android sources. iOS chooses the fixed widget dimensions, so compact sizes show fewer rows. Choose the large widget and the Home Screen’s Light or Dark appearance for the original colour palette.

**For the app and Home Screen widget, choose `ClashTimers-AltStore.ipa` and install it with AltStore Classic.** Your Windows PC runs AltServer for installation and refresh. The iPhone runs the app and its timers.

### 1. Get the iPhone build

In a GitHub repository containing **this iOS port**, open **Actions → Build iPhone app**. Open a successful run, download the **ClashTimers-iPhone** artifact, and extract the ZIP on Windows. A GitHub account is needed to download workflow artifacts. If you already have the IPA, skip to step 2.

If this copy exists only on your PC, you can run the build on GitHub’s Mac runner. From the top of this checkout, using [GitHub CLI](https://cli.github.com/):

```powershell
gh auth login
gh auth setup-git
gh repo fork Kuswaa/clash-timers --clone=false --remote=false
```

Open your new fork’s **Actions** tab and enable workflows if prompted. Then push **the local port** (a fork alone only contains the Android version):

```powershell
$owner = gh api user --jq .login
git push "https://github.com/$owner/clash-timers.git" HEAD:refs/heads/ios-support
```

That push starts **Build iPhone app**. It tests the timer engine, builds the device apps, verifies the AltStore package’s shared storage entitlements, and runs the simulator checks before uploading the IPAs. Private repositories use your [GitHub Actions allowance](https://docs.github.com/en/actions/concepts/billing-and-usage).

### 2. Install the app and widget with AltStore Classic

1. Follow the [AltStore Classic Windows setup](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) to install iTunes, iCloud and AltServer. Connect and trust your iPhone via USB, enable Wi-Fi sync in iTunes, then use **AltServer → Install AltStore**. Trust your developer profile and enable **Developer Mode** on the phone when prompted.
2. Copy **ClashTimers-AltStore.ipa** to iCloud Drive on Windows. Wait until it appears in **Files → Browse → iCloud Drive** on your iPhone. You can also download and extract the GitHub artifact in Files.
3. Keep AltServer running and connect over USB or the same Wi-Fi. On your iPhone, open **AltStore Classic → My Apps → +**, pick **ClashTimers-AltStore.ipa**, and **keep the app extensions** if asked. AltStore signs the app and its widget for your Apple account. Each needs an available App ID.
4. Open **Clash Timers**, import your village as described below, then touch and hold an empty part of your Home Screen. Tap **Edit → Add Widget** (or **+** on iOS 17), find **Clash Timers**, choose a size, and tap **Add Widget**.
5. With a free Apple account, use **AltStore → My Apps → Refresh All** while connected to AltServer before the seven days expire. See [refreshing apps](https://faq.altstore.io/altstore-classic/your-altstore) and [App ID limits](https://faq.altstore.io/altstore-classic/app-ids).

The AltStore IPA carries an ad hoc signature on both executables requesting the same App Group. During installation, AltStore re-signs them and provides the personal team's group in each bundle's `ALTAppGroups`. The app writes the village to that group and the widget reads it.

### Optional app-only install

Use **ClashTimersStandalone-unsigned.ipa** in AltStore’s file picker to install only the app. It keeps its own local data, so import your village into that version. You can also install it with Sideloadly:

1. Install [Sideloadly for Windows](https://sideloadly.io/) and its listed Apple device drivers. Connect your iPhone by USB, unlock it, and trust the computer.
2. Open Sideloadly. Select the iPhone and **ClashTimersStandalone-unsigned.ipa**. Use **Apple ID Sideload** and follow the signing prompts on your PC. Nothing needs to be sent to this project or its maintainers.
3. On the iPhone, trust the developer profile under **Settings → General → VPN & Device Management** if prompted. Enable [Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device) if iOS requests it, then open **Clash Timers**.
4. With a free Apple account, refresh the app before its seven-day signature expires. Use the same Apple account and bundle ID to retain your data. See the [Sideloadly FAQ](https://sideloadly.io/faq).

**ClashTimers-unsigned.ipa** is the input for other signing setups that supply entitlements and profiles for both the app and widget. For AltStore, use the specifically named **ClashTimers-AltStore.ipa**.

### Optional: signed build with the widget, without a Mac

If you have Apple development or ad hoc device profiles, the **Sign iPhone app with widget** workflow can sign both targets on GitHub’s Mac runner. It runs only in a **private repository** because the resulting IPA embeds the profiles’ registered device IDs.

1. Put this port on the private repo’s **default branch**. In your [Apple Developer account](https://developer.apple.com/help/account/provisioning-profiles/create-a-development-provisioning-profile/), create two explicit App IDs: your chosen ID and that ID followed by `.widget`. Enable the **same [App Group](https://developer.apple.com/documentation/xcode/configuring-app-groups)** for both. Generate a profile for each, using the same certificate and including your iPhone in both.
2. Add Actions secrets named `IOS_CERTIFICATE_P12`, `IOS_CERTIFICATE_PASSWORD`, `IOS_APP_PROFILE`, and `IOS_WIDGET_PROFILE`. The first, third, and fourth are the **base64 contents** of your `.p12` (certificate **and private key**) and two `.mobileprovision` files. The password is the `.p12` password. For example, from PowerShell in the private repo, `[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\signing\app.mobileprovision')) | gh secret set IOS_APP_PROFILE`. Do not commit signing files.
3. Run **Actions → Sign iPhone app with widget → Run workflow**. Download the **ClashTimers-provisioned** artifact, extract the `.ipa`, and install it on a registered device using Sideloadly’s **Normal Install** mode, which preserves the existing signature.

## First sync

1. In Clash of Clans, choose **Settings → More Settings → Data Export → Copy**.
2. In Clash Timers, tap **Import your village** (or the gold **Import** button), **Paste**, then **Import**. The app only accepts a complete village export. An invalid or older export for the same tag leaves your saved timers intact. The village is saved on your iPhone: simply reopening the app does not need another export.
3. Use **Log a potion or snack** after using a boost in the game. The icons are actions for recording uses; they do not represent your owned items or stock counts. Repeated uses queue them; **Undo** removes a queued boost or stops a running one without losing time already saved. The person button on an upgrade links or unlinks its helper.
4. Enable **Settings → Finish alerts** if desired. Alerts are scheduled locally and tapping one opens Clash Timers. A fresh sync or a changed prediction replaces obsolete alerts.
5. With the full build, add **Clash Timers** from your Home Screen widget gallery. The small widget shows the next finish, the medium widget shows one row per category, and the large widget shows the detailed builder, lab and pet sections. The large widget keeps the original brown panel, green progress rows, game icons and Lilita One font. Its **Log** buttons record boosts, the minus buttons undo them, and the green plus buttons link helpers directly. **Import** opens the paste screen. iOS draws the countdown; [WidgetKit controls the timing of layout refreshes](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date).

The game export is a snapshot. Copy a new one after changing upgrades in-game. Helper finish times assume future helper sessions are activated; the next export corrects the estimate. Importing a different player tag starts a separate calculation and discards the previous village’s boosts and links. The app tracks one village at a time.

## Build with Xcode or run the tests

On a Mac with Xcode 16 or later, open `ClashTimers.xcodeproj`. Select **ClashTimers** for the full app or **ClashTimersStandalone** for the app-only variant. Select an iPhone simulator and press **Run**. To install on a physical device, choose your team in Signing & Capabilities, set a unique `APP_BUNDLE_IDENTIFIER` in `Config/Versions.xcconfig`, and register the matching App Group for both full-build targets.

From `ios/`:

```sh
swift test                         # Portable timer + persistence tests (also works on Linux)
bash scripts/test-simulator.sh      # Xcode: app import, error recovery, boost/undo, relaunch
bash scripts/build-device.sh        # Xcode: AltStore IPA and two unsigned IPAs in build/artifacts/
```

`Sources/ClashTimersCore` is shared by the app and widget. Its bundled names, durations, and test exports match the Android assets; CI checks these copies for drift. The app and interactive widget update the saved document through one locked read-modify-write operation and read atomic snapshots from the App Group. The standalone target saves the same document in its private Application Support directory.

Code is covered by the repository [LICENSE](../LICENSE). Game data and names have separate [notices](../NOTICE). This is unofficial fan content and is not endorsed by Supercell.
