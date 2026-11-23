# Gate 0 runbook

Exact steps for the owner to run on real devices. They answer the three Gate 0 checks in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) and record the Phase 1 trace files. Nothing here can be done in the Simulator.

| Gate 0 check | Pass | Answered by |
|---|---|---|
| Watch keeps ranging with the app in the background or screen off | 2+ h without stopping | Part C, watch CSV |
| Watch battery used over 4 h armed | under 15% | Part C, watch CSV |
| iPhone keeps ranging when locked | 2+ h | Part C, phone CSV |

**Time needed:** about 30 minutes for parts A and B, then one 4-hour session per watch model (part C), then about 30 minutes for the traces (part D).

## What you need
- The iPhone, and two Apple Watch models: one older UWB model (Series 6 to 8) and one Series 9 or later. Run parts A to C once per watch.
- A Mac with Xcode, and your Apple developer team set on all three targets (Signing & Capabilities). Don't commit the team ID.
- Both devices charged to **80% or more**, and off the charger for the whole session.
- A helper for one trace in part D.

Write down as you go: iPhone model and iOS version, watch model and watchOS version, the commit you built (`git rev-parse --short HEAD`), and the clock time of each step marked **Note the time**.

## Part A: install and first run (10 minutes)
1. In Xcode, run the `PTPApp` scheme on the iPhone. The watch app installs with it; if it doesn't appear on the watch, run the `PTPWatch` scheme on the watch.
2. Open PTP on the iPhone. Allow every prompt: Nearby Interaction, Bluetooth, Live Activities.
3. Open PTP on the watch. Allow Nearby Interaction and Bluetooth.
4. Hold the devices within 1 m of each other. Check each screen:

   | Screen | Expect |
   |---|---|
   | iPhone | "Watch link: paired · app installed · reachable", then "Ranging" and a distance |
   | iPhone | "Heartbeat: answering" |
   | iPhone | "Log: N rows", with N climbing |
   | Watch | "iPhone link: reachable", then "Ranging" and a distance |
   | Watch | "Heartbeat: receiving" and "Last beat" staying near 1 second |
   | Watch | "Log: N rows", with N climbing |

5. If any line is wrong, stop and report exactly what both screens say. Don't continue to part B.

## Part B: short checks (20 minutes)
Each answers one unticked task in section 0.2 of the plan.

1. **Distance (#27).** Put the phone on a table and walk away with the watch until the watch says "Peer out of range". Write down the last distance you saw. Walk back; it should return to "Ranging".
2. **Locked phone (#29).** Lock the phone. The Lock Screen shows the PTP Live Activity with a distance. Walk 3 m away and back. Does the Lock Screen distance change? Write yes or no.
3. **Heartbeat (#37).** With the phone still locked, watch "Last beat" on the watch for 1 minute. It should stay near 1 second. Then walk out of range: "Last beat" should start counting up.
4. **Keep-alive modes (#35).** Do this twice, once per mode.
   1. On the watch, tap **Keep alive: runtime** (second time: **Keep alive: workout**; allow the Health prompt). **Note the time.**
   2. Write down the line under the buttons.
   3. Lower your wrist and leave the watch alone for 15 minutes. Keep the phone within 2 m.
   4. Raise your wrist. Write down the line under the buttons and the timer. Tap **Stop**.
5. **Log transfer (#39).** On the watch, tap **Send logs to phone**. Wait up to 2 minutes with both apps open. On the iPhone, open Files › On My iPhone › PTP. You should see `ptp-phone-….diagnostics.csv` and `ptp-watch-….diagnostics.csv` files.

## Part C: the 4-hour session (once per watch model)
Use the keep-alive mode that was still running after 15 minutes in part B. If both were, use **workout** (the runtime mode is expected to end after about 1 hour). If neither was, stop and report.

1. Charge both devices to 80% or more, then unplug them.
2. Force-quit PTP on both devices, so each starts a new log file.
   - iPhone: swipe up from the bottom, then swipe PTP away.
   - Watch: double-click the Digital Crown, then swipe PTP left and tap the red X.
3. Open PTP on the iPhone **and** on the watch (neither can range until both are open). Then wait for "Ranging" on both, and "Heartbeat: receiving" on the watch.
4. On the watch, tap the keep-alive mode. **Note the time**, and the battery % of both devices from their own status displays.
5. Lock the iPhone and put it in your pocket or bag. Lower your wrist.
6. Carry on normally for **4 hours**, keeping the phone on you, within about 2 m of the watch.
   - Don't open PTP on either device. Don't charge either device.
   - Use the phone and watch as you normally would otherwise.
7. After 4 hours: **note the time** and both battery percentages. Raise your wrist and write down the keep-alive line and timer on the watch.
8. Unlock the iPhone and open PTP. On the watch, tap **Send logs to phone**. Wait until the newest `ptp-watch-…` file in Files › On My iPhone › PTP stops growing (up to 5 minutes for a 4-hour log).
9. Tap **Stop** on the watch.

## Part D: trace recordings (30 minutes)
Each scenario needs its own log file, so **force-quit and reopen PTP on both devices before each one** (part C, steps 2 and 3), and start the keep-alive mode on the watch. For each, **note the time** of the moment in bold.

| Scenario | What to do |
|---|---|
| `table-walk-away` | Phone on a table. Stand next to it for 30 s. **Walk away** at a normal pace to 15 m. Wait 30 s. Walk back. |
| `snatch-run` | Phone in your hand. A helper **takes it and runs** 20 m away, waits 30 s, and comes back. |
| `pocket-crowd` | Phone in your trouser pocket, locked. Spend 10 minutes in a busy place (a shop queue, a station). The phone never leaves you. |
| `airplane-mode` | Phone in your hand, 1 m from the watch. After 60 s, **switch on Airplane Mode** on the phone. Wait 60 s. Switch it off. |
| `bag-noise` | Phone locked in a bag you're carrying. Walk for 10 minutes, including stairs if you can. The phone never leaves you. |

After the last one, tap **Send logs to phone** on the watch and wait for the files.

**Safety:** only use your own phone and a helper who has agreed. Don't stage a "theft" where bystanders could react.

## Getting the files to the Mac
1. On the iPhone: Files › On My iPhone › PTP. Select all the `.diagnostics.csv` files and AirDrop them to the Mac.
2. Put them in a folder **outside the repo**, for example `~/ptp-gate0/`. Never commit them (hard rule 6).

## Reading a 4-hour log
Run this on each part C file. It works on both the phone's and the watch's.

```bash
awk -F, 'NR>1 { if (!a) a=$1; z=$1 } NR>1 && $3=="uwb" && $2!="" { if (p && $1-p>g) g=$1-p; p=$1; n++; if (!f) f=$1; l=$1; if ($2+0>m) m=$2+0 } NR>1 && $5!="" { if (b0=="") b0=$5; b1=$5 } END { printf "Log covers: %.1f min\nUWB readings: %d over %.1f min\nLongest gap between readings: %.1f s\nLargest distance: %.2f m\nBattery in the log: %s%% -> %s%%\n", (z-a)/60000, n, (l-f)/60000, g/1000, m, b0, b1 }' ~/ptp-gate0/FILE.csv
```

```bash
awk -F, 'NR>1 { c[$3" "$4]++ } END { for (k in c) print c[k], k }' ~/ptp-gate0/FILE.csv
```

| Line | Pass for Gate 0 |
|---|---|
| "Log covers: N min" | N is about 240. If it's less, the app stopped getting readings before the session ended: the log's battery line then covers only that part, so use the battery percentages you noted at the start and end (part C, steps 4 and 7) |
| "UWB readings … over N min" (watch file) | N is 120 or more, **and** the second command shows `uwb background` rows |
| "Longest gap between readings" | Report the number. A gap of minutes means ranging stopped and restarted; the gate says "without stopping" |
| "Battery in the log: X% -> Y%" (watch file) | X minus Y is under 15, **only if** the log covers the full 4 hours. Otherwise use your noted percentages |
| "UWB readings … over N min" (phone file) | N is 120 or more, with `uwb background` rows from the locked period |
| `ble background` rows (both files) | Not a gate check, but it says whether the fallback (heartbeat only) would survive |

If the watch passes on the heartbeat but not on UWB, that's the plan's fallback: say so, don't call the gate passed.

## What to send back
Tell the agent the folder path and paste your notes. It runs the commands above, logs the session with `/log-field-drill`, and turns the part D files into fixtures (fixture columns only, times starting at 0).

```
iPhone: <model>, iOS <version>
Watch: <model>, watchOS <version>
Build: <commit>
Part A: all lines as expected? yes / no (what differed)
B1 largest distance before "Peer out of range": … m
B2 Lock Screen distance changed while locked: yes / no
B3 "Last beat" stayed near 1 s while locked: yes / no
B4 runtime: line at start …, line and timer after 15 min …
B4 workout: line at start …, line and timer after 15 min …
B5 watch files arrived on the phone: yes / no
C mode used: …  start time …  end time …
C battery, phone: …% -> …%   watch: …% -> …%
C watch keep-alive line and timer at the end: …
D start time and the bold moment's time, per scenario: …
Anything odd: …
```
