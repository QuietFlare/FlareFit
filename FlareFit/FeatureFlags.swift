//
//  FeatureFlags.swift
//  FlareFit
//

enum FeatureFlags {
    /// Phase 2: account-gated AI features (photo→plan import, AI plan designer,
    /// ElevenLabs voice selection). Off for the v1 store release — the code
    /// stays in place, just unreachable.
    static let aiFeaturesEnabled = false

    /// Live Activity (Dynamic Island / lock-screen countdown card). Off for v1:
    /// the countdown animates fine while suspended, but the phase title still
    /// freezes on-device (the known ActivityKit suspension bug), so it can look
    /// broken mid-workout. The in-app screen + coach voice carry the workout
    /// instead. The extension stays in place (dormant) — flip this back on to
    /// revive the card. Orphan cleanup still runs at launch so any card from an
    /// older build gets dismissed.
    static let liveActivityEnabled = false
}
