//
//  ElevenLabsVoice.swift
//  FlareFit
//
//  Generates natural coach voice lines via the ElevenLabs API and caches
//  them as MP3s on device. Workouts play from cache — instant and offline.
//

import Foundation
import CryptoKit

enum ElevenLabsError: LocalizedError {
    case missingKey
    case api(status: Int, detail: String)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "No ElevenLabs API key set."
        case .api(let status, let detail):
            switch status {
            case 401: return "ElevenLabs rejected the API key (401). Check the key in Settings."
            case 429: return "ElevenLabs rate limit or quota reached (429)."
            default: return "ElevenLabs error (HTTP \(status)): \(detail)"
            }
        }
    }
}

final class ElevenLabsVoice {
    static let shared = ElevenLabsVoice()

    private static let voiceIDKey = "elevenLabsVoiceID"
    private let modelID = "eleven_turbo_v2_5"

    private var isPreparing = false

    /// The voice we've resolved for this account (free accounts can only use
    /// their own premade voices via the API, so we pick one of those).
    private var currentVoiceID: String {
        UserDefaults.standard.string(forKey: Self.voiceIDKey) ?? "default"
    }

    private init() {}

    var isConfigured: Bool {
        !(KeychainHelper.loadElevenLabsKey() ?? "").isEmpty
    }

    // MARK: - Cache

    private var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("VoiceCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cacheFile(for text: String) -> URL {
        let digest = SHA256.hash(data: Data("\(currentVoiceID)|\(text)".utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent("\(name).mp3")
    }

    /// Returns the cached clip for this phrase, or nil if not generated yet.
    func cachedClip(for text: String) -> URL? {
        let url = cacheFile(for: text)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Generation

    /// Generate any missing phrases, one at a time (free tier allows limited
    /// concurrency). Safe to call repeatedly — already-cached phrases are skipped.
    func prepare(phrases: [String]) async {
        guard isConfigured, !isPreparing else { return }
        isPreparing = true
        defer { isPreparing = false }

        for phrase in Set(phrases) where cachedClip(for: phrase) == nil {
            try? await synthesize(phrase)
        }
    }

    @discardableResult
    func synthesize(_ text: String) async throws -> URL {
        try await synthesize(text, allowRetry: true)
    }

    private func synthesize(_ text: String, allowRetry: Bool) async throws -> URL {
        guard let apiKey = KeychainHelper.loadElevenLabsKey(), !apiKey.isEmpty else {
            throw ElevenLabsError.missingKey
        }

        let voiceID = try await resolveVoiceID(apiKey: apiKey)

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.elevenlabs.io"
        components.path = "/v1/text-to-speech/\(voiceID)"
        components.queryItems = [URLQueryItem(name: "output_format", value: "mp3_44100_128")]
        guard let requestURL = components.url else {
            throw ElevenLabsError.api(status: -1, detail: "Invalid voice ID.")
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "model_id": modelID,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let detail = String(data: data, encoding: .utf8).map { String($0.prefix(200)) } ?? ""
            #if DEBUG
            print("ElevenLabs synthesis failed (\(status)): \(detail)")
            #endif

            // Voice not usable on this account/plan — forget it and re-resolve.
            if status == 402 || status == 404 {
                UserDefaults.standard.removeObject(forKey: Self.voiceIDKey)
                if allowRetry {
                    return try await synthesize(text, allowRetry: false)
                }
            }
            throw ElevenLabsError.api(status: status, detail: detail)
        }

        let url = cacheFile(for: text)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Ask ElevenLabs which voices this account can use and pick a premade one
    /// (free accounts can use their premade voices via the API, but not
    /// Voice Library voices). Cached in UserDefaults after the first lookup.
    private func resolveVoiceID(apiKey: String) async throws -> String {
        if let stored = UserDefaults.standard.string(forKey: Self.voiceIDKey) {
            return stored
        }

        guard let voicesURL = URL(string: "https://api.elevenlabs.io/v1/voices") else {
            throw ElevenLabsError.api(status: -1, detail: "Invalid URL.")
        }
        var request = URLRequest(url: voicesURL)
        request.timeoutInterval = 30
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let detail = String(data: data, encoding: .utf8).map { String($0.prefix(200)) } ?? ""
            throw ElevenLabsError.api(status: status, detail: detail)
        }

        struct VoicesResponse: Decodable {
            struct Voice: Decodable {
                // Mirrors ElevenLabs' JSON field name.
                // swiftlint:disable:next identifier_name
                let voice_id: String
                let name: String?
                let category: String?
            }
            let voices: [Voice]
        }

        let list = try JSONDecoder().decode(VoicesResponse.self, from: data)
        guard let chosen = list.voices.first(where: { $0.category == "premade" }) ?? list.voices.first else {
            throw ElevenLabsError.api(status: 404, detail: "No voices available on this account.")
        }

        #if DEBUG
        print("ElevenLabs: using voice \(chosen.name ?? chosen.voice_id)")
        #endif
        UserDefaults.standard.set(chosen.voice_id, forKey: Self.voiceIDKey)
        return chosen.voice_id
    }
}
