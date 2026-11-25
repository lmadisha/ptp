# Privacy

**Summary:** PTP has no servers. Everything it stores stays on your iPhone and Apple Watch, and nothing is sent to us or anyone else.

## Data the app stores
| Data | Why | Where | How long |
|---|---|---|---|
| Settings | To work the way you set it up | iPhone + watch | Until you delete the app |
| Arm mode on the watch (normal or event) | So the watch stays armed and can alarm without the phone if the app restarts | UserDefaults on the watch | Until disarm or marking the phone as lost |
| The watch's state (one word: disarmed, armed, warning, alarm or lost) | So the iPhone can show what the watch is doing | Handed to the system's WatchConnectivity link, which keeps the latest value on your iPhone and watch | Replaced on every state change; removed from each device when you delete PTP on that device |
| The end time of a running event on the watch | So Event mode ends when you chose, also after the watch app restarts | UserDefaults on the watch | Until the event ends, you disarm, or you mark the phone as lost. If an Alarm is showing when the event ends, until you leave the Alarm |
| Alarm or Lost state on the watch | So an Alarm isn't cleared when the watch app restarts | UserDefaults on the watch | Until the owner leaves that state |
| Place areas you visit: for each visit, a grid cell about 250 m across and the day you arrived. No exact coordinates, no times of day, no departures (ADR-0010) | To tell when you're somewhere unfamiliar | iPhone only, in an on-device SQLite database that's file-protected and not backed up to iCloud | Each visit is deleted 60 days after its day, the next time the app opens or records a visit. "Delete learned places" removes them all |
| Safe places and risky places you choose | To arm or not arm automatically | iPhone only | Until you remove them |
| Alarm history: the time the iPhone learned of an Alarm on the watch, the time it learned the Alarm had ended, and one word for each (the watch's state: alarm, armed, warning, lost or disarmed). No distance and no location | To tune detection and show you past alerts | iPhone only, in an on-device SQLite database that's file-protected and not backed up to iCloud | Deleted once older than 30 days, the next time the app opens or logs an event |
| Phone–watch distance | To detect separation | In the app's memory, plus the test-build reading log in the next row | Not kept by the app, apart from that log |
| Reading log (test builds, Phase 0): the time, the distance, the signal (UWB or Bluetooth), whether the app was in front or in the background, the battery level, and on the watch the Bluetooth signal strength of the heartbeat. No location, no names, no device identifiers | To measure whether the watch and phone can stay armed for hours, and to record test traces | A CSV file per app launch in the app's Documents folder on each device, not backed up to iCloud. The iPhone's folder shows in the Files app. The watch's files are copied to the iPhone only when you tap "Send logs to phone" | Until you delete the file or the app. The log is removed from the app before public release; after that, distance is written only to diagnostics you export yourself |
| Latest distance, ranging state and the watch's state (one word) shown in the Live Activity. Anyone holding the locked phone can read it, including a red "Alarm" | So you can see the link on the Lock Screen and in the Dynamic Island while the phone is locked | Handed to the system's Live Activity on your iPhone (no push server, nothing leaves the phone) | Replaced on every update; the system removes it when the activity ends or is dismissed (at most 8 hours, plus up to 4 hours on the Lock Screen after ending) |
| Nearby Interaction discovery token (a random identifier for one ranging session; no location or personal data) | So the phone and watch can find each other to measure distance | Handed to the system's WatchConnectivity link, which keeps the latest token on your iPhone and watch and passes it to the other device | Replaced by each new ranging session; removed when you delete the app |

## Permissions
| Permission | Used for | If you refuse |
|---|---|---|
| Nearby Interaction | Measuring the distance between phone and watch | The app can't work; Bluetooth-only mode is offered |
| Location (Always) | New-area prompt and risky or safe places | Event mode and manual arming still work |
| Notifications | New-area prompt (asked when place learning starts; the notification says only "New area" and carries no place) and alarms | No new-area prompt; places are still learned. Alarms only show while the app is open |
| Bluetooth | A heartbeat between your iPhone and watch. The watch asks once per interval, and the phone answers with a random session ID plus a counter, so the watch notices when the phone is gone. The session ID is new every time the app starts, isn't stored, and is shared with the watch only over its private link. Any nearby Bluetooth device could read that random ID, but it identifies nothing and changes every launch | Distance falls back to UWB only; the heartbeat signal is lost |
| Health (workouts, write only) | Phase 0 spike: a workout session is started only to keep the watch app running while armed. No health data is read, and no workout is saved to Health. | The workout keep-alive mode can't start; the extended-runtime mode still works |

## Sharing
- Nothing is shared automatically.
- **Export diagnostics** saves a file on your phone. It goes to the developer only if you choose to send it.

## Your control
- Delete all learned places with "Delete learned places" on the iPhone (Settings › Places once settings exist).
- Deleting the app removes all of its data.

## Legal
The app follows the Protection of Personal Information Act (POPIA) by processing location data only on the device and only for the stated purpose.

*Have this reviewed before publishing; it is not legal advice.*
