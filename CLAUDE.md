# FlareFit — iOS Workout Timer (SwiftUI)

Native iOS workout assistant by Seema (Quietflare, quietflare.net). Free app, no accounts,
no servers, everything on-device.

> Private working notes (roadmap, monetization, review considerations) are kept OUTSIDE this repo
> in the maintainer's workspace — not part of this public repo or its history.

## Build & test (headless)
- Build: `xcodebuild -project FlareFit.xcodeproj -scheme FlareFit` (or the Claude iOS Simulator MCP build tool)
- Tests: `xcodebuild test -project FlareFit.xcodeproj -scheme FlareFit -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FlareFitTests`
- Debug auto-start hook: `xcrun simctl launch booted net.quietflare.flarefit -autostartWorkout` (DEBUG builds; starts a short deterministic workout — see FlareFitApp.init)
- Bypass welcome screen in sim: `xcrun simctl spawn booted defaults write net.quietflare.flarefit hasSeenWelcome -bool YES`

## Architecture (all in FlareFit/, Xcode 16 synchronized folders — files auto-join targets)
- `WorkoutEngine.swift` — THE core. Flattens a plan into `[WorkoutStep]` (`buildSteps`, static, pure,
  unit-tested). Wall-clock timing (`stepEndDate`), suspension catch-up (`catchUp`), publishes Live
  Activity states. `WorkoutPlan`/`Exercise` in `Models.swift`: exercise reps = work+rest cycles; plan
  repetitions = rounds; switch timer bridges exercises (rest only *between* reps — never rest+switch).
- `WorkoutCoordinator.swift` — @MainActor singleton owning the active engine; UI + Siri both drive it;
  logs history; starts/stops BackgroundAudioKeeper + LiveActivityManager.
- `SpeechCoach.swift` — bundled clip playback (BundledVoice/*.mp3: 7 phrases × en/de × f/m,
  `coach_{lang}_{gender}_{key}.mp3`), native TTS fallback, generated tick tones, audio-session
  duck-only-while-speaking. Prefs: CoachPrefs (language auto/en/de, gender f/m).
- `AudioSupport.swift` — ToneGenerator (WAV in memory) + BackgroundAudioKeeper (near-silent 100Hz
  loop keep-alive + interruption recovery).
- `LiveActivityManager.swift` + `FlareFitWidgets/FlareFitWidgetsLiveActivity.swift` — Live Activity
  (lock screen + Dynamic Island). `WorkoutActivityAttributes` is DUPLICATED in both files — keep in sync!
- `FlareFitIntents.swift` — Siri App Intents (start/pause/skip/end/music). In-workout intents return
  silently (coach voice is the confirmation).
- `ReminderScheduler.swift` — per-plan weekly local notifications (PlanReminder on WorkoutPlan).
- `HistoryStore.swift`/`HistoryView.swift` — auto workout logs, week stats. Tab 2 of the app.
- `FeatureFlags.aiFeaturesEnabled = false` — hides phase-2 AI features (photo→plan import via
  `PlanImporter.swift`, ElevenLabs settings). Code kept, unreachable in v1.
- `Support/Info.plist` — partial plist merged into generated one (UIBackgroundModes audio,
  ITSAppUsesNonExemptEncryption, NSSupportsLiveActivitiesFrequentUpdates).
- `tools/make_clips.py` — regenerates voice clips via ElevenLabs API (picks premade voices by gender label).

## OPEN BUG (locked-screen coaching — DEFERRED past v1 by product decision)
Live Activity phase updates freeze on-device (iPhone 12, iOS 18.6.2): exactly ONE transition renders
per lock, then only self-animating timers move. Root cause: iOS suspends the app when locked despite
the audio keeper. So while the screen is locked, the in-app timer/voice can pause until the app is
woken. v1 SHIPS WITHOUT a locked-screen coaching fix — accepted tradeoff (see below).

REMOVED (was implemented, then cut — too noisy): the per-phase local-notification coaching
(`WorkoutPlaybackServices.swift` + `NotificationCoach` + `WorkoutPhaseSchedule.swift` +
`WorkoutEngine.remainingPhases` + CAF notification sounds). It fired a notification at EVERY phase
boundary so voice cues played while suspended, but that meant a banner per phase — too spammy;
notifications should be ONLY per-plan reminders. All of it deleted; recover from git history if
revived. NOTE: `ReminderScheduler` (per-plan weekly reminders) is a SEPARATE, untouched system —
that's the only notification source in v1, and it asks for permission only when the user enables a
reminder (ContentView).

Future options for locked-screen coaching (post-v1): lock-screen phase widget (needs App Group) or
ActivityKit push (needs a backend). Both were prototyped/discussed; see git history.

Live Activity is OFF in v1 (FeatureFlags.liveActivityEnabled=false — gates the .start() call in
WorkoutCoordinator; update/finish/end then no-op on the nil activity). Reason: the countdown animates
fine while suspended but the phase title freezes on-device, so it can look broken. Extension stays in
place (dormant, still builds the LiveActivity widget); LiveActivityManager.cleanupOrphans() still runs
at launch to dismiss any card from an older build. Flip the flag on to revive it.

SHELVED for v1: the lock-screen phase *widget* — a WidgetKit timeline (one entry per phase) reading a
deterministic schedule from an App Group. Prototype removed (WorkoutPhaseWidget.swift, the widget-side
WorkoutPhaseSchedule copy, both entitlements' app-group keys, pbxproj wiring) — recover from git history.

## Pre-ship checklist (v1 = no AI, no phase widget)
- ✅ Removed "· v2" marker (FlareFitWidgetsLiveActivity) + LiveActivity DEBUG prints
- ✅ Icon: replaced the SF Symbol flame.fill app icon (license violation for app icons) with a
  custom-drawn dumbbell + timer-arc on the ember gradient — `tools/make_icon.swift` (run:
  `swift tools/make_icon.swift FlareFit/Assets.xcassets/AppIcon.appiconset/AppIcon.png arc`).
  Output is flattened to opaque RGB (no alpha) as the App Store requires. Brand direction is now
  DUMBBELL (not flame): in-app brand marks use `dumbbell.fill` — AboutView logo, WelcomeView hero,
  PlanRow avatar (ContentView), Plans tab. The flame is KEPT only as a semantic icon on the "Ns work"
  label (ContentView ~445 — means burn/effort), and in the dormant Live Activity/widget UI (off in v1).
  SF Symbols in-app are fine under the license; only the app-icon use was the violation.
- ✅ Voice clips: regenerated under a paid ElevenLabs plan (commercial license). Pin voices via
  `COACH_VOICE_F` / `COACH_VOICE_M` env (voice IDs) — `tools/make_clips.py --list` shows the account's
  voices; the auto-picker now fails loudly rather than mis-gendering (that was a bug — free-lib name/
  label drift made it grab any voice). rm-first still REQUIRED when regenerating (script skips existing).
- ✅ Privacy manifest: FlareFit/PrivacyInfo.xcprivacy — NSPrivacyTracking=false, no collected data,
  UserDefaults required-reason CA92.1. (Widget target uses no required-reason APIs → none needed.)
- Background audio: BackgroundAudioKeeper uses UIBackgroundModes=audio to keep coaching + music alive
  when backgrounded. (Review considerations kept in the maintainer's private notes, outside this repo.)
- App Store Connect (at submission): privacy nutrition label = "Data Not Collected"; category
  Health & Fitness; age rating; screenshots; description. Export compliance already declared
  (ITSAppUsesNonExemptEncryption=false). No tracking/IDFA, no accounts → no ATT / Sign-in-with-Apple.
- ✅ Bundle ID: `net.quietflare.flarefit` (matches the quietflare.net domain, lowercase-canonical,
  scales to a `net.quietflare.*` app family). Widget ext = `net.quietflare.flarefit.widgets`, tests =
  `net.quietflare.flarefitTests` / `…flarefitUITests`. Permanent once first shipped.
- Privacy page: deploy the /flarefit/privacy page (in the quietflare website repo) before submission.

## v1.1 roadmap
Post-launch AI photo→plan import (behind FeatureFlags.aiFeaturesEnabled=false). Monetization and
backend design are kept in the maintainer's private notes, outside this repo.

## CI/CD (GitHub Actions)
- `.github/workflows/ci.yml` — SwiftLint + build + FlareFitTests on PRs + manual dispatch (macos, Xcode
  pinned to '16' — latest-stable = Xcode 26.x has no iOS sim runtime on the runner). NOT on every push,
  to save macOS minutes. SwiftLint step is continue-on-error until a green run confirms it.
- `.github/workflows/ai-review.yml` — PR code-review agent via PR-Agent (qodo, open source) driving
  Google Gemini Flash. Ubuntu runner. Needs repo secret `GEMINI_API_KEY` (aistudio.google.com/apikey).
  ⚠️ VERIFY PR-Agent's action ref + env-var keys + model string against its current docs — they drift.
  Model-agnostic (swap config.model + provider key for groq/deepseek/openai). Skips bot PRs.
- `.github/workflows/codeql.yml` — CodeQL SAST. Currently artifact-only + manual (Security-tab upload
  needs GitHub Advanced Security, which was unavailable on a private repo). NOW PUBLIC → code scanning
  is free: restore `security-events: write`, drop `upload: false` + the artifact step, add push/PR/
  schedule triggers to publish to the Security tab. (No third-party deps → classic SCA is a no-op.)
- `.github/dependabot.yml` — weekly github-actions version bumps (bot PRs skipped by ai-review/CI gates).
- `.github/workflows/testflight.yml` — archive + upload to TestFlight, triggered by a `v*` tag or manual
  dispatch. Needs 3 repo secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (App Store Connect API
  key). Uses cloud signing (`-allowProvisioningUpdates` + `-authenticationKey*`), no certs in the repo.
  `.github/ExportOptions.plist` holds the export config — verify `teamID` matches the signing team.
- `.gitignore` covers DerivedData/xcuserdata/archives/keys + `*.private.md` (safety net). BundledVoice
  MP3s, AppIcon.png, PrivacyInfo.xcprivacy are intentionally NOT ignored (must ship).

## Conventions
- v1 scope is locked: core timer + plans + music + Siri + per-plan reminders + history. No AI, no
  phase widget, no per-phase workout notifications, no locked-screen coaching in v1. The ONLY
  notifications are per-plan weekly reminders (ReminderScheduler).
- All engine behavior changes need a WorkoutEngineTests case (that's how the rest+switch double-timer
  bug stays dead).
- Prefer honest tradeoff explanations and store-guideline compliance checks before building.
