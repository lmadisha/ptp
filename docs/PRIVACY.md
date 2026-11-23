# Privacy

**Summary:** PTP has no servers. Everything it stores stays on your iPhone and Apple Watch, and nothing is sent to us or anyone else.

## Data the app stores
| Data | Why | Where | How long |
|---|---|---|---|
| Settings | To work the way you set it up | iPhone + watch | Until you delete the app |
| Place areas you visit, with a visit count (rounded, not exact trails) | To tell when you're somewhere unfamiliar | iPhone only, in an on-device SQLite database that's file-protected and not backed up to iCloud | Deleted after 60 days |
| Safe places and risky places you choose | To arm or not arm automatically | iPhone only | Until you remove them |
| Alarm history | To tune detection and show you past alerts | iPhone only | About 30 days |
| Phone–watch distance | To detect separation | In the app's memory only, never written to a file by the app (except in diagnostics you export yourself) | Not kept by the app |
| Latest distance and ranging state shown in the Live Activity | So you can see the link on the Lock Screen and in the Dynamic Island while the phone is locked | Handed to the system's Live Activity on your iPhone (no push server, nothing leaves the phone) | Replaced on every update; the system removes it when the activity ends or is dismissed (at most 8 hours, plus up to 4 hours on the Lock Screen after ending) |
| Nearby Interaction discovery token (a random identifier for one ranging session; no location or personal data) | So the phone and watch can find each other to measure distance | Handed to the system's WatchConnectivity link, which keeps the latest token on your iPhone and watch and passes it to the other device | Replaced by each new ranging session; removed when you delete the app |

## Permissions
| Permission | Used for | If you refuse |
|---|---|---|
| Nearby Interaction | Measuring the distance between phone and watch | The app can't work; Bluetooth-only mode is offered |
| Location (Always) | New-area prompt and risky or safe places | Event mode and manual arming still work |
| Notifications | New-area prompt and alarms | Alarms only show while the app is open |
| Bluetooth | A heartbeat between your iPhone and watch. The watch asks once per interval, and the phone answers with a random session ID plus a counter, so the watch notices when the phone is gone. The session ID is new every time the app starts, isn't stored, and is shared with the watch only over its private link. Any nearby Bluetooth device could read that random ID, but it identifies nothing and changes every launch | Distance falls back to UWB only; the heartbeat signal is lost |
| Health (workouts, write only) | Phase 0 spike: a workout session is started only to keep the watch app running while armed. No health data is read, and no workout is saved to Health. | The workout keep-alive mode can't start; the extended-runtime mode still works |

## Sharing
- Nothing is shared automatically.
- **Export diagnostics** saves a file on your phone. It goes to the developer only if you choose to send it.

## Your control
- Delete all learned places in Settings › Places.
- Deleting the app removes all of its data.

## Legal
The app follows the Protection of Personal Information Act (POPIA) by processing location data only on the device and only for the stated purpose.

*Have this reviewed before publishing; it is not legal advice.*
