# FlareFit

**A voice-coached interval workout timer for iOS.** Build your own plans, then just move — a clear voice
coach calls every work, rest, and switch so you never have to look at the screen, while your own music
keeps playing underneath. No accounts, no servers, no tracking — everything stays on your device.

By [Quietflare](https://quietflare.net).

## Features
- **Custom plans** — exercises, reps, rounds, and work / rest / switch timers
- **Voice coaching** — spoken cues with countdown ticks (English & German, female / male)
- **Plays over your music** — ducks only while the coach speaks
- **Hands-free with Siri** — start, pause, skip, or end via App Intents
- **Per-plan weekly reminders** — local notifications, opt-in
- **Automatic history** — workout logs and weekly stats

## Requirements
- iOS 18.2+
- Xcode 16

## Build & run
```bash
# Command line
xcodebuild -project FlareFit.xcodeproj -scheme FlareFit

# Or just open FlareFit.xcodeproj in Xcode and ⌘R
```

## Tests
```bash
xcodebuild test -project FlareFit.xcodeproj -scheme FlareFit \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:FlareFitTests
```

## Architecture
The core is `WorkoutEngine.swift` — it flattens a plan into an ordered list of timed steps up front
(`buildSteps`, pure and unit-tested) and drives them on wall-clock time so the workout stays accurate
across backgrounding. See [`CLAUDE.md`](CLAUDE.md) for a full map of the codebase.

## Privacy
FlareFit collects no data and contacts no servers. Everything — your plans, history, and settings —
lives only on your device. See the bundled privacy manifest (`FlareFit/PrivacyInfo.xcprivacy`).

## License
Source-available under the **PolyForm Noncommercial License 1.0.0** — see [`LICENSE`](LICENSE).
You're welcome to read, learn from, and use FlareFit for **noncommercial** purposes, but not to sell
it or ship it (or a derivative) commercially. Copyright © 2026 Seema Jagadeesh / Quietflare.
