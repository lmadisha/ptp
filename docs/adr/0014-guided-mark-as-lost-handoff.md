# ADR-0014: The Mark as Lost hand-off is guided steps, not a deep link

- **Status:** Proposed
- **Date:** 2026-11-26

## Context
ADR-0001 says that on Alarm "the watch takes the owner straight to Find My's Mark as Lost", aiming for under 15 s from alert to action. The plan asked to open Find Devices on the watch, with icloud.com/find as a fallback.

watchOS gives third-party apps no supported way to open Find Devices:
- [`openSystemURL`](https://developer.apple.com/documentation/watchkit/wkapplication/opensystemurl(_:)) handles only `tel:` and `sms:`;
- SwiftUI `openURL` reliably handles those and Universal Links only;
- Find Devices has no documented URL scheme.

Undocumented schemes exist in leaked system plists, but relying on them is unsupported and could break or be rejected. That goes against hard rule 2.

## Decision
After "Mark as Lost", the watch's Lost screen is the hand-off:
1. Four short numbered steps: press the Digital Crown, open Find Devices, tap your iPhone, turn on Mark As Lost.
2. Then the fallback: "Or use icloud.com/find on another device."

The steps are plain text, read in order by VoiceOver, with "Done" below them to start a new session. No URL scheme is tried.

## Consequences
- The owner leaves PTP by hand. That costs a few seconds against the 15 s Gate 2 target, and the owner drill measures it.
- Apple's on-watch labels can change between watchOS versions. The steps must be checked against the current Find Devices app at each major release.
- Revisit if Apple documents a Find Devices or Find My URL, App Intent or `openSystemURL` support. Then the hand-off becomes one tap.
