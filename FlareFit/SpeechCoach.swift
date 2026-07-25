import AVFoundation
import AudioToolbox
import Foundation

/// User preferences for the coach voice.
enum CoachPrefs {
    static let languageKey = "coachLanguage" // "auto" | "en" | "de"
    static let genderKey = "coachGender"     // "f" | "m"

    /// Resolves "auto" to the device language (German devices get the German coach).
    static var resolvedLanguage: String {
        let pref = UserDefaults.standard.string(forKey: languageKey) ?? "auto"
        guard pref == "auto" else { return pref }
        return (Locale.preferredLanguages.first ?? "en").hasPrefix("de") ? "de" : "en"
    }

    static var gender: String {
        UserDefaults.standard.string(forKey: genderKey) ?? "f"
    }
}

/// Speaks workout cues. Prefers bundled studio clips; falls back to the
/// on-device speech synthesizer. Music is ducked only while the coach is
/// actually speaking — in between, the session stays in .mixWithOthers so
/// music plays at full volume (and BackgroundAudioKeeper keeps the app
/// alive when the screen is locked).
///
/// @unchecked Sendable: held by @MainActor types; delegate callbacks arrive
/// on AVFoundation's internal queue but only touch thread-safe AVFoundation
/// objects and the audio session.
final class SpeechCoach: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate, @unchecked Sendable {
    static let voiceDefaultsKey = "speechVoiceIdentifier"

    private let synthesizer = AVSpeechSynthesizer()
    private var clipPlayer: AVAudioPlayer?
    private var tickPlayer: AVAudioPlayer?
    var isMuted = false

    // Generated once — short beeps that work in the background (system
    // sounds don't play reliably when the screen is locked).
    private static let tickData = ToneGenerator.tone(frequency: 1000, seconds: 0.09, amplitude: 0.35)
    private static let finalTickData = ToneGenerator.tone(frequency: 1400, seconds: 0.14, amplitude: 0.45)

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Voice selection

    private var voice: AVSpeechSynthesisVoice? {
        if let id = UserDefaults.standard.string(forKey: Self.voiceDefaultsKey),
           let chosen = AVSpeechSynthesisVoice(identifier: id) {
            return chosen
        }
        return Self.bestAvailableVoice()
    }

    /// English voices sorted best-first (Premium > Enhanced > Standard).
    static func availableVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { rank($0) > rank($1) }
    }

    static func bestAvailableVoice() -> AVSpeechSynthesisVoice? {
        availableVoices().first ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    private static func rank(_ voice: AVSpeechSynthesisVoice) -> Int {
        var score = 0
        switch voice.quality {
        case .premium: score += 100
        case .enhanced: score += 50
        default: break
        }
        if voice.language == AVSpeechSynthesisVoice.currentLanguageCode() { score += 10 }
        return score
    }

    static func qualityLabel(for voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: return "Premium"
        case .enhanced: return "Enhanced"
        default: return "Standard"
        }
    }

    // MARK: - Speaking

    func say(_ text: String) {
        guard !isMuted else { return }

        stopCurrentAudio()
        #if os(iOS)
        // Duck music while speaking; restored in the delegate callbacks.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers])
        try? session.setActive(true)
        #endif

        if let clip = clipURL(for: text),
           let player = try? AVAudioPlayer(contentsOf: clip) {
            clipPlayer = player
            player.delegate = self
            player.play()
        } else {
            // No clip for this line — speak natively, translated if needed.
            let lang = CoachPrefs.resolvedLanguage
            let phrase = Self.phrases[text]
            let spokenText = (lang == "de" ? phrase?.de : nil) ?? text

            let utterance = AVSpeechUtterance(string: spokenText)
            utterance.voice = lang == "de"
                ? AVSpeechSynthesisVoice(language: "de-DE")
                : voice
            utterance.rate = 0.5
            utterance.pitchMultiplier = 1.05
            utterance.volume = 1.0
            synthesizer.speak(utterance)

            if FeatureFlags.aiFeaturesEnabled && ElevenLabsVoice.shared.isConfigured {
                Task.detached(priority: .utility) {
                    try? await ElevenLabsVoice.shared.synthesize(text)
                }
            }
        }
    }

    /// Bundled studio clips first (shipped with the app, work for everyone),
    /// respecting the user's language and voice preference. Falls back to the
    /// user's ElevenLabs cache (phase 2 feature).
    private func clipURL(for text: String) -> URL? {
        if let phrase = Self.phrases[text] {
            let name = "coach_\(CoachPrefs.resolvedLanguage)_\(CoachPrefs.gender)_\(phrase.key)"
            if let url = Bundle.main.url(forResource: name, withExtension: "mp3")
                ?? Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "BundledVoice") {
                return url
            }
        }
        if FeatureFlags.aiFeaturesEnabled {
            return ElevenLabsVoice.shared.cachedClip(for: text)
        }
        return nil
    }

    private struct Phrase {
        let key: String
        let de: String
    }

    /// Keyed by the canonical (English) announcement text the engine produces.
    private static let phrases: [String: Phrase] = [
        "Get ready!": Phrase(key: "get_ready", de: "Mach dich bereit!"),
        "Work!": Phrase(key: "work", de: "Los geht's!"),
        "Rest.": Phrase(key: "rest", de: "Pause."),
        "Switch!": Phrase(key: "switch", de: "Wechsel!"),
        "Workout complete. Well done!": Phrase(key: "complete", de: "Training geschafft. Gut gemacht!"),
        "Paused.": Phrase(key: "paused", de: "Angehalten."),
        "Resumed.": Phrase(key: "resumed", de: "Weiter geht's."),
    ]

    /// Crisp tick instead of a spoken number — cuts through music much better.
    /// The final tick (1 second left) uses a distinct sound. Generated tones
    /// play even when the app is in the background.
    func countdownTick(_ secondsRemaining: Int) {
        guard !isMuted else { return }
        tickPlayer = try? AVAudioPlayer(data: secondsRemaining == 1 ? Self.finalTickData : Self.tickData)
        tickPlayer?.play()
    }

    func stop() {
        stopCurrentAudio()
    }

    private func stopCurrentAudio() {
        synthesizer.stopSpeaking(at: .immediate)
        clipPlayer?.stop()
        clipPlayer = nil
    }

    // MARK: - Delegates

    // Release the audio session when done speaking so music returns to full volume.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        deactivateSessionIfIdle()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        deactivateSessionIfIdle()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        clipPlayer = nil
        deactivateSessionIfIdle()
    }

    private func deactivateSessionIfIdle() {
        #if os(iOS)
        guard !synthesizer.isSpeaking, clipPlayer?.isPlaying != true else { return }
        let session = AVAudioSession.sharedInstance()
        if BackgroundAudioKeeper.shared.isRunning {
            // Workout in progress — un-duck the music but keep the session
            // alive so timers survive the screen locking.
            try? session.setCategory(.playback, options: [.mixWithOthers])
            try? session.setActive(true)
        } else {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
        #endif
    }
}
