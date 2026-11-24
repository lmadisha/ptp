# ADR-0009: Judge by the heartbeat's signal strength when there is no UWB distance

- **Status:** Proposed
- **Date:** 2026-11-24

## Context
The watch only ranges with UWB while PTP is in the foreground (ADR-0004). With PTP off screen it gets the Bluetooth heartbeat only. ADR-0007 decision 2 keeps the last range verdict while the heartbeat arrives, and Bluetooth reaches far beyond the alert distance. The owner found the result on devices (#57): with PTP off screen, walking away from the phone raises no alarm. ADR-0007 listed this as a gap; it is the normal case whenever the owner leaves the app.

The owner chose to build the rule now with provisional thresholds, before any device log of signal strength exists (#67).

## Decision
1. **The watch reads the heartbeat connection's signal strength (RSSI, in dBm) after every beat** and passes it to the state machine with the next heartbeat sample, so a value is one beat old and the first beat of a connection carries none. The reading log records it (`rssi_dbm`).
2. **A fresh UWB distance always decides.** Fresh means newer than `DetectionConfig.uwbFreshness` (2 s). Signal strength is ignored while it is.
3. **Without a fresh distance, signal strength decides**, by its median over `rssiWindow` (5 s), once the window holds at least `rssiMinSamples` (3) readings:
   - weaker than `farRSSI` (−85 dBm): out of range. The usual Warning and Alarm delays follow.
   - stronger than `nearRSSI` (−70 dBm): in range, but only against a verdict that signal strength itself raised. A strong signal never clears a verdict that a UWB distance raised: Bluetooth can stay strong well past the alert distance, and ADR-0007 already rejected cancelling a countdown that way.
   - between the two: the last verdict stands, so a signal hovering at one level can't flap.
4. **"I have it" clears the signal window**, as it clears the distance window (ADR-0007). After the tap a weak signal raises nothing until the signal has been strong once or a UWB distance arrives. Without this, a phone in a pocket with a steadily weak signal would alarm again every ten seconds, and Disarm would be the only way out. So does a suspension: readings from before it decide nothing afterwards.
5. **The thresholds are provisional.** They are guesses, not measurements. They must be set from the owner's device logs (the #67 drills) before anyone relies on them.
   - Rejected: keep ADR-0007 decision 2 as it was. No alarm off screen is the failure the product exists to prevent.
   - Rejected: turn signal strength into metres. It can't carry that precision; three bands are all it supports.
   - Rejected: wait for the device logs before building. The owner's choice; the cost is below.

This replaces the second half of ADR-0007 decision 2 ("only a new distance changes the verdict"). The rest of ADR-0007 stands.

## Consequences
- **False alarms are likely until the thresholds are tuned.** A body between the wrist and a pocket can weaken the signal as much as ten metres of open air. `pocket-crowd` is the trace most at risk, and it now has two ways to fail: UWB flicker (already handled) and a weak signal with PTP off screen.
- **Missed alarms remain possible.** A phone carried away in clear line of sight can keep a strong signal well past the alert distance. Signal loss (ADR-0007 decision 1) is still the backstop.
- An Alarm from signal strength can come later than one from UWB: after arming, "I have it" or a suspension the window needs three readings (about 2 s at one beat per second) before the usual 2 s and 5 s delays start. When UWB merely goes stale the window is already full.
- **Event mode gets no tighter signal levels.** The same −85 and −70 dBm apply at the 4 m and the 8 m alert distance, so off screen Event mode protects at whatever distance −85 dBm turns out to be.
- A mistaken "I have it" silences signal strength until the signal is strong again or PTP is back on screen. Signal loss still alarms.
- The rule is tested with synthetic samples only. The #67 drill logs become the first fixtures.
- If the logs show that no pair of thresholds separates "in my pocket" from "walked away" on the owner's devices, this decision has to change: for example a Warning only, with no Alarm from signal strength.
- The watch must be alive in the background for any of this to run (#57). That is still unconfirmed on devices.
