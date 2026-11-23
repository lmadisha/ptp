# Security Policy

PTP is a safety app, so security and privacy bugs get priority.

## Reporting a vulnerability
**Do not open a public issue.** Instead:
- Use GitHub's **Report a vulnerability** (Security tab → Advisories), or
- email the maintainer at [SECURITY CONTACT EMAIL].

Include:
- what you found and its impact
- steps to reproduce
- device models and OS versions

**Response times:**
- Acknowledgement within 5 working days.
- A fix plan within 14 days for confirmed issues.

## In scope
- Ways to stop or silence an alarm without the owner (beyond killing the app, which is a known limit).
- Location or place data leaving the device, or readable by other apps.
- Spoofing the watch–phone pairing or distance.
- Anything that leaks data through exported diagnostics.

## Out of scope
- iOS cannot stop a thief from force-quitting the app or switching on airplane mode. PTP treats signal loss as an alarm by design (see `docs/adr/0004`).
- PTP does not lock the phone. That is Find My's job (see `docs/adr/0001`).
