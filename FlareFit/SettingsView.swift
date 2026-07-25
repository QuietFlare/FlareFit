//
//  SettingsView.swift
//  FlareFit
//

import SwiftUI
import AVFoundation
import AppIntents

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(CoachPrefs.languageKey) private var coachLanguage = "auto"
    @AppStorage(CoachPrefs.genderKey) private var coachGender = "f"
    @State private var apiKey: String = KeychainHelper.loadAPIKey() ?? ""
    @State private var elevenLabsKey: String = KeychainHelper.loadElevenLabsKey() ?? ""
    @State private var voiceTestStatus: String?
    @State private var isTestingVoice = false
    private let previewCoach = SpeechCoach()

    var body: some View {
        NavigationStack {
            Form {
                coachVoiceSection
                siriSection
                if FeatureFlags.aiFeaturesEnabled {
                    elevenLabsSection
                    apiKeySection
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: apiKey) {
                KeychainHelper.saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            .onChange(of: elevenLabsKey) {
                KeychainHelper.saveElevenLabsKey(elevenLabsKey.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        KeychainHelper.saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                        KeychainHelper.saveElevenLabsKey(elevenLabsKey.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                }
            }
        }
    }

    private var coachVoiceSection: some View {
        Section {
            Picker("Language", selection: $coachLanguage) {
                Text("Automatic").tag("auto")
                Text("English").tag("en")
                Text("Deutsch").tag("de")
            }
            Picker("Voice", selection: $coachGender) {
                Text("Female").tag("f")
                Text("Male").tag("m")
            }
            Button {
                previewCoach.say("Get ready!")
            } label: {
                Label("Preview Voice", systemImage: "play.circle")
            }
        } header: {
            Text("Coach Voice")
        } footer: {
            Text("Automatic follows your device language (English or German).")
        }
    }

    private var siriSection: some View {
        Section {
            // Shows the actual, working Siri phrase (with the app name) and lets
            // the user add it — the reliable way to teach the command.
            SiriTipView(intent: StartWorkoutIntent())
            ShortcutsLink()
        } header: {
            Text("Siri & Shortcuts")
        } footer: {
            Text("Start hands-free — say a phrase like “Hey Siri, start my workout in FlareFit.” Include “in FlareFit” so Siri knows it's this app. Tap above to see every shortcut, or add your own phrase.")
        }
    }

    private var elevenLabsSection: some View {
        Section {
            SecureField("ElevenLabs API key", text: $elevenLabsKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

            Button {
                Task { await testNaturalVoice() }
            } label: {
                if isTestingVoice {
                    HStack {
                        ProgressView()
                        Text("Testing…").padding(.leading, 8)
                    }
                } else {
                    Label("Test Natural Voice", systemImage: "waveform")
                }
            }
            .disabled(elevenLabsKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTestingVoice)

            if let voiceTestStatus {
                Text(voiceTestStatus)
                    .font(.caption)
                    .foregroundStyle(voiceTestStatus.hasPrefix("✅") ? .green : .red)
            }
        } header: {
            Text("Natural Voice (ElevenLabs)")
        } footer: {
            Text("When set, coach lines are generated with a natural ElevenLabs voice and cached on device — workouts stay fully offline. Free key at elevenlabs.io (Profile → API Keys). If a line isn't generated yet, the built-in iOS voice fills in.")
        }
    }

    private func testNaturalVoice() async {
        isTestingVoice = true
        voiceTestStatus = nil
        defer { isTestingVoice = false }

        // Make sure the freshly typed key is what we test with.
        KeychainHelper.saveElevenLabsKey(elevenLabsKey.trimmingCharacters(in: .whitespacesAndNewlines))

        let sample = "Voice check successful. Let's get to work!"
        do {
            _ = try await ElevenLabsVoice.shared.synthesize(sample)
            previewCoach.say(sample)  // plays the freshly cached clip
            voiceTestStatus = "✅ Working — this is the voice you'll hear in workouts."
        } catch {
            voiceTestStatus = "❌ \(error.localizedDescription)"
        }
    }

    private var apiKeySection: some View {
        Section {
            SecureField("sk-ant-…", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
        } header: {
            Text("Anthropic API Key")
        } footer: {
            Text("Used for the AI photo-to-plan feature. Stored securely in the iOS Keychain and only ever sent to api.anthropic.com. Get a key at console.anthropic.com.")
        }
    }
}

#Preview {
    SettingsView()
}
