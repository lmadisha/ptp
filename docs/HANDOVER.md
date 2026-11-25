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
1. **Gate 0 is recorded as passed** (2026-11-24, on the owner's device check, #54). Still open, and they need the owner:
   - 4-hour armed sessions on two watch models. The 2026-11-24 drill projects about 33 points of watch battery over 4 h against the gate's under 15%, so this is the check most likely to fail;
   - recording the trace scenarios (the trace-replay task in Phase 1.1 stays open until fixtures exist).
   Write exact steps for the owner and wait. Don't guess. Use `/log-field-drill` once results come back.
2. **Phase 1 may go ahead** now that Gate 0 is recorded as passed. If the 4-hour battery run fails, follow the plan's fallback (Bluetooth heartbeat only) and re-plan.

## Device checks the owner still owes
The full steps, in order, are in [GATE0_RUNBOOK.md](GATE0_RUNBOOK.md). In short:
- **#25 and #27:** install both apps with the team set. Both screens should show "Peer token received", then "Ranging" with a distance that changes as you walk apart. Note the largest distance before "Peer out of range".
- **#29:** lock the phone while ranging. The Lock Screen distance should keep updating. Time how long it keeps going.
- **#35:** on the watch, try "Keep alive: runtime", then "Keep alive: workout", each with the wrist down. Note how long each keeps running.
- **#37:** the watch shows "Last beat" at about 1 s with the phone locked; it grows when the phone is out of range.
- **#39:** run both apps for a few minutes, lock the phone, walk away and back. In Files › On My iPhone › PTP the phone's CSV has rows through the locked period. Tap "Send logs to phone" on the watch; its CSV appears in the same folder (a transfer can take a minute).
- **#49:** on the watch, tap Arm with the phone app running nearby: it stays "Armed". Note how many seconds pass before a distance replaces "No distance reading"; that is the link start-up time, which `linkStartupDelay` (10 s) must cover. Switch the phone to airplane mode (or force-quit the phone app): the watch shows "Alarm" about 3 s later. Tap "I have it", then force-quit the watch app and reopen it: it comes back "Armed" and should stay there once the link is back. Repeat with the wrist down to see whether the alarm still arrives.
- **#50:** the old watch readings and buttons (#35, #37, #39) are now under Disarmed › Diagnostics. Arm, then walk away from the phone: past 8 m the bar fills, and 2 s later the screen turns amber with one tap on the wrist and a countdown from 5. "I have it" returns to Armed. Let a countdown run out: the screen turns red and the wrist taps about once a second until you tap "I have it", "Mark as Lost" or Disarm. Check that you feel and hear it with the wrist down, and with the watch in silent mode.
- **#51:** (a) Arm, then lower the wrist for longer than the keep-alive lasts (about 1 h for the runtime session) with the phone nearby. Raise the wrist and open PTP if the watch face shows instead. The watch should be Armed, not Alarm. Note whether it says "Not protected", whether you felt a tap when the keep-alive ended, and whether opening the app clears the line: a restart from the background is expected to fail, so this drill decides whether the runtime session is enough. (b) Arm, lower the wrist until the app is suspended, switch the phone to airplane mode, then raise the wrist: Alarm within about 10 s. (c) Raise an Alarm, force-quit the watch app and reopen it: still Alarm, haptic repeating. (d) Mark as Lost, force-quit and reopen: still the Lost screen.
- **#57:** the owner reported the watch app stopping after a few minutes and not running in the background. The cause is not confirmed (no device log). After this fix: tap Arm on the watch with the phone app open, lower the wrist for 15 minutes, keep the phone within 2 m. Raise the wrist and open PTP if the watch face shows. The screen can't tell you whether the app was restarted, because a restarted app re-arms itself. Instead tap Disarm, then Diagnostics › "Send logs to phone", and count the `ptp-watch-….diagnostics.csv` files in Files › On My iPhone › PTP: each launch starts a new file, so more than one file for the 15 minutes means the app was restarted, and the file names give the times. Also note the keep-alive line and "Last beat" on Diagnostics. If it stops again, connect the iPhone to the Mac and wait a few minutes so the watch logs sync.
- **#59:** with both apps open, the iPhone shows "Watch: Disarmed". Tap Arm on the watch: the phone line changes to "Watch: Armed" (it can take a few seconds). Raise an Alarm by walking away past 8 m and letting the Warning run out (airplane mode on the phone won't do here, because it also cuts the link): the phone shows "Watch: Alarm". Repeat the Alarm with the wrist down and the phone app in the background, then open the phone app: does it show Alarm, and how late? Note how long each change takes to appear, and what the phone shows after the watch app is force-quit (it is expected to keep the last state).
- **#61:** with the phone locked, the Lock Screen activity reads "PTP · Disarmed". Arm on the watch: it reads "PTP · Armed". Raise an Alarm (walk away past 8 m): it turns red and reads "PTP · Alarm". Tap "I have it" on the watch: it goes back to black. Note how long each change takes with the phone locked, and whether red ever stays after the watch has left Alarm.
- **#65:** the phone shows "Alarm log: N events". Raise an Alarm on the watch with the phone app open: N goes up by one. Tap "I have it": N goes up by one more. Force-quit and reopen the phone app during an Alarm: N must not go up again. Repeat with the phone locked in a pocket, then open the app: were both entries written?
- **#67 (do these first; they set the thresholds):** install the build, open Disarmed › Diagnostics on the watch and check "Signal: … dBm" shows a number with the phone app open. Then, for each drill, tap Arm, press the Digital Crown so PTP is off screen, and note the clock time you start and stop:
  1. **Pocket:** phone in a trouser pocket, walk around and sit, 3 minutes. Expected: no tap on the wrist. Note any.
  2. **Bag:** phone in a bag on your shoulder, 3 minutes. Expected: none.
  3. **Walk away:** phone on a table, walk 20 m in a straight line, wait 20 s, walk back. Twice. Expected: a tap (Warning), then repeated taps (Alarm). Note how far you were.
  4. **Other room:** phone on a table, go behind a wall for 1 minute. Expected: taps.
  5. **Airplane mode:** PTP off screen, switch the phone to airplane mode. Expected: taps within a few seconds. Nothing until you reopen PTP means the app is not alive in the background (#57).
  6. **Wrist down:** arm, do not press the crown, lower the wrist, walk away. Does it alarm?
  7. **Warning, then off screen:** with PTP on screen walk to about 9 m until the Warning shows, then press the crown and keep walking. The Alarm must still come.
  8. **Pocket after "I have it":** if drill 1 or 2 alarmed, tap "I have it" and keep the phone where it was for 2 minutes. Expected: no second alarm.
  Afterwards open PTP, Disarm, Diagnostics › "Send logs to phone", and copy the `ptp-watch-…` files from Files › On My iPhone › PTP to the Mac. They are raw logs: do not commit them.
- **#69:** on the watch's Disarmed screen tap "Event 2 hours". The Armed screen shows "Event · ends" with a time two hours ahead, and the Warning now comes at about 4 m, not 8 m. Force-quit and reopen the watch app: the same end time shows. To see the end without waiting two hours, leave it armed and check after the end time: it should read Disarmed. If an Alarm is showing when the time is up, it must stay until you tap "I have it"; the watch then disarms once the phone has answered, with a tap on the wrist. Note what the watch does after the first hour, when the keep-alive runs out (#57).
- **#73:** open PTP on both devices with the watch on Disarmed. The phone's "Event 2 hours" and "Event 4 hours" buttons are enabled. Tap one: the watch arms and shows "Event · ends", and the phone's line changes to "Watch: Armed" with the buttons greyed out. Then disarm on the watch and press the crown (PTP off screen): are the phone's buttons greyed out, with the line asking you to open PTP on the watch? Last, with the watch on Disarmed, lower your wrist and tap an Event button on the phone within about 2 seconds: the watch should not arm, and the phone should keep showing "Watch: Disarmed". Note how long the watch takes to arm after a normal tap.
- **#76:** on the iPhone tap "Learn places" and allow location "Always" (iOS first offers only "While Using App". Choose it: "Learn places" disappears, and iOS later asks on its own whether to keep allowing PTP in the background; choose "Change to Always Allow". If you refused, or chose "Keep Only While Using", the button reads "Allow location “Always” in Settings" and opens PTP's Settings page; check it does). The phone shows "Places learned: 0 areas". Carry the phone as usual for two days, going to at least three places and staying 15+ minutes at each. Then open PTP: the count should be about the number of distinct places you stayed at. Note the count and the places (names only, not addresses; do not commit them). Tap "Delete learned places": the count goes back to 0. Also check that refusing location leaves the Event buttons working.
- **#78:** after #76 is set up, open PTP on the iPhone and allow notifications when asked. With the watch on Disarmed and worn, lock the phone and go somewhere you have not been since learning started; stay 15+ minutes. Expected: the watch shows "New area · Arm PTP on your watch?" with an "Arm" button. Tap "Arm": PTP opens on the watch and shows Armed (normal, 8 m). Note how long after arriving the prompt came, and whether it showed on the phone, the watch or both. Go back to the same place on three more days: it prompts on the first three days, not on the fourth. Also check that dismissing the notification leaves the watch Disarmed, and that tapping "Arm" on the phone (phone unlocked) only opens PTP on the phone and leaves the watch Disarmed.
- **#80:** with place learning on (#76), stand somewhere you want to mark (not home) and tap "Mark here as risky"; the line shows "Risky places: 1". Nothing should prompt while you are there. Walk at least 300 m away, lock the phone, wear the watch on Disarmed, and come back. Expected: the watch shows "Risky place · Arm PTP on your watch?" with "Arm"; tapping it arms. Note how long after arriving it came. At home tap "Mark here as safe", then check over the next days that no "New area" prompt comes at home. Finally tap "Remove chosen places": both counts go to 0.
- **#83:** on the watch, long-press the face, tap Edit, swipe to the complications page and choose a slot › PTPWatch › "Arm PTP". Press the crown. With PTP on Disarmed and closed, tap the complication: PTP opens on Armed. Tap it again while armed: nothing changes. Note whether it shows on your usual face, and how long PTP takes to open.

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
