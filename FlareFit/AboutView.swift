//
//  AboutView.swift
//  FlareFit
//

import SwiftUI

// This view holds the Terms / Disclaimer / Privacy legal copy as long string
// literals — line length isn't meaningful for prose.
// swiftlint:disable line_length

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(LinearGradient.ember)
                                .frame(width: 92, height: 92)
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
                        }
                        Text("FlareFit")
                            .font(.title.bold())
                        Text("Version \(version)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("Voice-coached interval workouts.\nEverything stays on your device.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                Section("Legal") {
                    NavigationLink {
                        LegalTextView(title: "Terms of Use", text: LegalText.terms)
                    } label: {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                    NavigationLink {
                        LegalTextView(title: "Fitness Disclaimer", text: LegalText.disclaimer)
                    } label: {
                        Label("Fitness Disclaimer", systemImage: "heart.text.square")
                    }
                    NavigationLink {
                        LegalTextView(title: "Privacy", text: LegalText.privacy)
                    } label: {
                        Label("Privacy", systemImage: "lock.shield")
                    }
                }

                Section {
                    Link(destination: URL(string: "https://www.quietflare.net")!) {
                        Label("quietflare.net", systemImage: "globe")
                    }
                } footer: {
                    Text("Made with 🔥 by Quietflare")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct LegalTextView: View {
    let title: String
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.callout)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum LegalText {
    static let terms = """
    Terms of Use

    Last updated: July 2026

    1. Acceptance. By using FlareFit ("the app"), you agree to these terms. If you do not agree, please do not use the app.

    2. What FlareFit is. FlareFit is a workout timer. It runs interval timers, plays audio cues and music, and stores workout plans that you create. It does not provide professional fitness, health, or medical advice.

    3. Your responsibility. You are solely responsible for your own health and safety while exercising. Always review the Fitness Disclaimer before using the app.

    4. Your content. Workout plans you create are stored only on your device. You own them. Deleting the app deletes them.

    5. No warranty. The app is provided "as is", without warranty of any kind. To the maximum extent permitted by law, Quietflare disclaims all warranties and shall not be liable for any damages arising from your use of the app, including injury, loss of data, or interrupted workouts.

    6. Changes. These terms may be updated with app updates. Continued use after an update constitutes acceptance.

    7. Contact. Questions? Visit quietflare.net.
    """

    static let disclaimer = """
    Fitness Disclaimer

    FlareFit is a timer, not a trainer, physician, or medical device.

    • Consult a qualified healthcare professional before beginning any exercise program, especially if you have a medical condition, are pregnant, or have not exercised in a long time.

    • Stop exercising immediately if you feel pain, dizziness, shortness of breath, or discomfort, and seek medical attention if needed.

    • Exercise involves inherent risk of injury. You use this app, and perform any workouts timed by it, entirely at your own risk.

    • Timer durations and workout structures in this app are set by you (or defaults) and are not personalized recommendations.

    Listen to your body. It knows more than any app.
    """

    static let privacy = """
    Privacy

    FlareFit is built to know as little about you as possible.

    • No account. No sign-up, no login, no email.

    • No data collection. We do not collect, transmit, or sell any personal data. There are no analytics or trackers in the app.

    • On-device storage. Your workout plans and settings are stored only on your device, and are deleted when you delete the app.

    • Music access. If you choose workout music, the app requests access to your media library solely to play it. Nothing about your library leaves the device.

    • Siri. Siri commands are processed by Apple according to Apple's own privacy policy. FlareFit only receives the resulting action (e.g. "start workout").

    Questions? Visit quietflare.net.
    """
}

#Preview {
    AboutView()
}

// swiftlint:enable line_length
