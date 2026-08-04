//
//  AudioSupport.swift
//  FlareFit
//
//  Background-audio keeper and generated tones.
//
//  iOS suspends apps shortly after they leave the foreground — which would
//  freeze workout timers. Playing a silent audio loop (with the "audio"
//  background mode) keeps the session alive, so the coach keeps coaching
//  with the screen locked or the phone in a pocket.
//

import AVFoundation

/// Generates small PCM WAV payloads in memory — no bundled assets needed.
enum ToneGenerator {
    private static let sampleRate = 44_100

    /// A sine-wave beep with a short fade-out to avoid clicks.
    static func tone(frequency: Double, seconds: Double, amplitude: Double) -> Data {
        let count = Int(Double(sampleRate) * seconds)
        var samples = [Int16](repeating: 0, count: count)
        let fadeSamples = max(count / 5, 1)
        for i in 0..<count {
            let envelope: Double
            if i > count - fadeSamples {
                envelope = Double(count - i) / Double(fadeSamples)
            } else if i < fadeSamples / 4 {
                envelope = Double(i) / Double(fadeSamples / 4)
            } else {
                envelope = 1.0
            }
            let value = sin(2.0 * .pi * frequency * Double(i) / Double(sampleRate))
            samples[i] = Int16(max(-1.0, min(1.0, value * amplitude * envelope)) * Double(Int16.max))
        }
        return wav(samples: samples)
    }

    static func silence(seconds: Double) -> Data {
        wav(samples: [Int16](repeating: 0, count: Int(Double(sampleRate) * seconds)))
    }

    private static func wav(samples: [Int16]) -> Data {
        var data = Data()
        let byteCount = samples.count * 2

        func append(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + byteCount))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append(16)                       // fmt chunk size
        append16(1)                      // PCM
        append16(1)                      // mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))   // byte rate
        append16(2)                      // block align
        append16(16)                     // bits per sample
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(byteCount))
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }
}

/// Configures the audio session for the duration of a workout so the coach and
/// the user's music play smoothly in the FOREGROUND: .mixWithOthers keeps music
/// at full volume, and the coach ducks it only while speaking. FlareFit is a
/// foreground workout timer — the screen is kept awake during a workout (see
/// WorkoutCoordinator) — so it declares NO background audio mode.
final class BackgroundAudioKeeper {
    static let shared = BackgroundAudioKeeper()

    private(set) var isRunning = false

    private init() {
        // A phone call (or Siri, or another app taking exclusive audio)
        // interrupts our session. When the interruption ends, re-activate it so
        // the coach keeps playing for the rest of the workout.
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self, self.isRunning,
                  let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
