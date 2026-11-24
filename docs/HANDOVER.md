# Handover

For the next AI agent (or human) picking up PTP. Read **AGENTS.md** first; every rule there still applies. This file adds what isn't written anywhere else: where things stand, what's next, and the practical gotchas. Last updated: 2026-11-23.

## Where things stand
- **Phase 0, task 0.1 (repo and project setup):** all six tasks are done and merged.
  - the Xcode project with three targets;
  - the `PTPCore` package;
  - the App Group `group.com.lmadisha.ptp`;
  - Info.plist keys (Nearby Interaction, `audio` and `location` background modes, Live Activities);
  - CI (`.github/workflows/ci.yml`);
  - minimum versions (iOS 18.4, watchOS 11).
- **Phase 0, task 0.2 (distance spike):**

  | Task | State |
  |---|---|
  | Token exchange over WatchConnectivity (#25, PR #26) | Merged, ticked |
  | NISession on both devices with live distance (#27, PR #28) | Merged. **Not ticked**: needs a device check |
  | Live Activity keeps iPhone ranging (#29, PR #34) | Merged. **Not ticked**: needs a device check |
  | Watch keep-alive: extended runtime + workout session (#35, PR #36) | Merged (spike buttons on the watch). **Not ticked**: device timing needed |
  | Bluetooth heartbeat as a second signal (#37, PR #38) | Merged (the watch reads, the phone answers). **Not ticked**: device check needed |
- **Phase 0, task 0.3 (measurement):**
  - CSV reading log (#39): implemented on `feat/39-reading-log`. Files are `ptp-<phone|watch>-<unix seconds>.diagnostics.csv` in each app's Documents folder; the phone's show in the Files app, and the watch sends its file with "Send logs to phone". Device check needed.
  - The 4-hour sessions and the trace recordings need the owner.
- **Storage decision:** ADR-0005 (merged in PR #31) switches on-device stores to SQLite in a `Packages/PTPStore` package. It's **Proposed**, so the owner must accept it.
- **Apple Developer portal:**
  - Registered on the owner's team: App Group `group.com.lmadisha.ptp`, and App IDs `com.lmadisha.ptp` and `com.lmadisha.ptp.LiveActivity` (both with App Groups linked), plus `com.lmadisha.ptp.watchkitapp`.
  - The team ID is deliberately **not** committed, because the repo is public. The owner sets the team in Xcode for device builds.

## Next tasks, in order
1. **Gate 0 needs the owner:**
   - 4-hour armed sessions on two watch models;
   - recording the trace scenarios;
   - the measurements in the Gate 0 table.
   Write exact steps for the owner and wait. Don't guess. Use `/log-field-drill` once results come back.
2. **Phase 1 starts only after Gate 0 passes** (plan rule). If it fails, follow the plan's fallback (Bluetooth heartbeat only) and re-plan.

## Device checks the owner still owes
The full steps, in order, are in [GATE0_RUNBOOK.md](GATE0_RUNBOOK.md). In short:
- **#25 and #27:** install both apps with the team set. Both screens should show "Peer token received", then "Ranging" with a distance that changes as you walk apart. Note the largest distance before "Peer out of range".
- **#29:** lock the phone while ranging. The Lock Screen distance should keep updating. Time how long it keeps going.
- **#35:** on the watch, try "Keep alive: runtime", then "Keep alive: workout", each with the wrist down. Note how long each keeps running.
- **#37:** the watch shows "Last beat" at about 1 s with the phone locked; it grows when the phone is out of range.
- **#39:** run both apps for a few minutes, lock the phone, walk away and back. In Files › On My iPhone › PTP the phone's CSV has rows through the locked period. Tap "Send logs to phone" on the watch; its CSV appears in the same folder (a transfer can take a minute).
- **#49:** on the watch, tap Arm with the phone app running nearby: it stays "Armed". Note how many seconds pass before a distance replaces "No distance reading"; that is the link start-up time, which `linkStartupDelay` (10 s) must cover. Switch the phone to airplane mode (or force-quit the phone app): the watch shows "Alarm" about 3 s later. Tap "I have it", then force-quit the watch app and reopen it: it comes back "Armed" and should stay there once the link is back. Repeat with the wrist down to see whether the alarm still arrives.
- **#50:** the old watch readings and buttons (#35, #37, #39) are now under Disarmed › Diagnostics. Arm, then walk away from the phone: past 8 m the bar fills, and 2 s later the screen turns amber with one tap on the wrist and a countdown from 5. "I have it" returns to Armed. Let a countdown run out: the screen turns red and the wrist taps about once a second until you tap "I have it", "Mark as Lost" or Disarm. Check that you feel and hear it with the wrist down, and with the watch in silent mode.
- **#57:** the owner reported the watch app stopping after a few minutes and not running in the background. The cause is not confirmed (no device log). After this fix: tap Arm on the watch with the phone app open, lower the wrist for 15 minutes, keep the phone within 2 m. Raise the wrist and open PTP if the watch face shows. The screen can't tell you whether the app was restarted, because a restarted app re-arms itself. Instead tap Disarm, then Diagnostics › "Send logs to phone", and count the `ptp-watch-….diagnostics.csv` files in Files › On My iPhone › PTP: each launch starts a new file, so more than one file for the 15 minutes means the app was restarted, and the file names give the times. Also note the keep-alive line and "Last beat" on Diagnostics. If it stops again, connect the iPhone to the Mac and wait a few minutes so the watch logs sync.

## Workflow as actually run (see AGENTS.md for the rules)
- **Roles:** Claude Opus plans and reviews; **Codex GPT-6.2 Sol implements** (the owner's choice); Claude Haiku captures Simulator evidence.
- **Codex CLI:** it ships inside the ChatGPT app, already signed in:
  `/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex exec -m gpt-6.2-sol -c model_reasoning_effort=medium -s workspace-write [--add-dir <spec dir>] -C <repo> -o <last-msg file> "<prompt>"`
  - Tell it: don't commit, push or switch branches.
  - **Its sandbox can't run `xcodebuild` or `swift build`**, because Xcode can't write its caches. The reviewer runs every build.
- **Codex cloud review** (the `chatgpt-codex-connector` bot) runs automatically **only when a PR is opened**.
  - After each push, comment `@codex review`.
  - Its state is in the `codex-review-state` HTML comment on the PR, and findings arrive as inline comments.
  - It has found real bugs on most PRs. Verify each finding, fix it, reply on the thread, then resolve it.
- **CI:** `macos-26` (arm64) runners are often short of capacity. "The job was not acquired by Runner … after multiple attempts" is GitHub capacity, not your code. Re-run with `gh run rerun <id> --failed`. CI runs on PRs and on pushes to `develop`/`main` only (see the #23 audit entry).
- **Merge conflicts:** almost every PR adds an entry at the top of `docs/audit-findings.md` and `CHANGELOG.md`. Merge `develop` into the branch and keep both entries; the audit log is newest first.
- **Graphify after every merge** (`/graphify . --update`):
  - It **skips any file with "token" in its name** as possibly secret, which catches `Shared/TokenExchange.swift`. That file has no secrets, so extract it by hand.
  - `graphify-out/` is gitignored and machine-local.

## Simulator notes
- **Paired Simulators:** iPhone 17 Pro and Apple Watch Series 11 (46 mm) are paired with `xcrun simctl pair`.
  - WatchConnectivity works between them.
  - `bootstatus` can take up to 5 minutes.
- **Nearby Interaction in the Simulator:** it reports support, issues tokens and "ranges" at a constant **0.0 m**. That proves the code paths, never real distance.
- **WatchConnectivity keeps the last application context** even after the other app is uninstalled. `TokenExchange` ignores a stored token unless the counterpart is installed.

## XcodeGen spec (copy of the working spec)
`PTP.xcodeproj` is the source of truth. It was generated with XcodeGen 2.48 from this spec, which was kept outside the repo. To change targets:
1. Save the spec below outside the repo.
2. Edit it.
3. Run `xcodegen generate --spec <path> --project-root <repo> --project <repo>`.
4. Review the `.pbxproj` diff.

Or edit the project in Xcode and stop using the spec. Fix the absolute path in `postGenCommand` for your machine. The `ActivityShared` source entries belong to #29.

```yaml
name: PTP
options:
  bundleIdPrefix: com.lmadisha
  createIntermediateGroups: true
  # Let Xcode supply bundle metadata. Keep only the explicit background modes here.
  postGenCommand: >-
    /usr/libexec/PlistBuddy
    -c 'Delete :CFBundleDevelopmentRegion'
    -c 'Delete :CFBundleExecutable'
    -c 'Delete :CFBundleIdentifier'
    -c 'Delete :CFBundleInfoDictionaryVersion'
    -c 'Delete :CFBundleName'
    -c 'Delete :CFBundlePackageType'
    -c 'Delete :CFBundleShortVersionString'
    -c 'Delete :CFBundleVersion'
    /ABSOLUTE/PATH/TO/ptp/PTPApp/Info.plist
settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_STRICT_CONCURRENCY: complete
    CODE_SIGN_STYLE: Automatic
    GENERATE_INFOPLIST_FILE: YES
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
packages:
  PTPCore:
    path: Packages/PTPCore
targets:
  PTPApp:
    type: application
    platform: iOS
    deploymentTarget: "18.4"
    sources: [PTPApp, Shared, ActivityShared]
    info:
      path: PTPApp/Info.plist
      properties:
        UIBackgroundModes: [audio, location]
    entitlements:
      path: PTPApp/PTPApp.entitlements
      properties:
        com.apple.security.application-groups: [group.com.lmadisha.ptp]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.lmadisha.ptp
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        INFOPLIST_KEY_NSNearbyInteractionUsageDescription: "PTP measures the distance between your iPhone and Apple Watch so it can warn you if they are separated. The distance stays on your devices."
        INFOPLIST_KEY_NSSupportsLiveActivities: YES
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
        INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait
        TARGETED_DEVICE_FAMILY: "1"
    dependencies:
      - package: PTPCore
      - target: PTPWatch
        embed: true
      - target: PTPLiveActivity
        embed: true
  PTPWatch:
    type: application
    platform: watchOS
    deploymentTarget: "11.0"
    sources: [PTPWatch, Shared]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.lmadisha.ptp.watchkitapp
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        INFOPLIST_KEY_NSNearbyInteractionUsageDescription: "PTP measures the distance between your iPhone and Apple Watch so it can warn you if they are separated. The distance stays on your devices."
        INFOPLIST_KEY_WKCompanionAppBundleIdentifier: com.lmadisha.ptp
        INFOPLIST_KEY_WKApplication: YES
    dependencies:
      - package: PTPCore
  PTPLiveActivity:
    type: app-extension
    platform: iOS
    deploymentTarget: "18.4"
    sources: [PTPLiveActivity, ActivityShared]
    entitlements:
      path: PTPLiveActivity/PTPLiveActivity.entitlements
      properties:
        com.apple.security.application-groups: [group.com.lmadisha.ptp]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.lmadisha.ptp.LiveActivity
        INFOPLIST_FILE: PTPLiveActivity/Info.plist
        INFOPLIST_KEY_CFBundleDisplayName: PTP
        SKIP_INSTALL: YES
        TARGETED_DEVICE_FAMILY: "1"
schemes:
  PTPApp:
    build:
      targets: {PTPApp: all}
    run: {config: Debug}
  PTPWatch:
    build:
      targets: {PTPWatch: all}
    run: {config: Debug}
```

## Open audit items
See `docs/audit-findings.md` (status `open`):
- the spike status lines and `tokenStatus`, to replace with the Phase 1 screens;
- `PTPCore.version`, to delete in Phase 1;
- the `location` background mode, to remove if Phase 2 changes course.

## Owner-only settings, not done
- **Branch protection** for `main` and `develop`, requiring `CI / test`. For example:
  `gh api -X PUT repos/lmadisha/ptp/branches/develop/protection -F required_status_checks[strict]=true -f 'required_status_checks[contexts][]=test' -F enforce_admins=false -F required_pull_request_reviews=null -F restrictions=null`
- **Accepting ADR-0004 and ADR-0005.**
