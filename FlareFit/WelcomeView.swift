//
//  WelcomeView.swift
//  FlareFit
//

import SwiftUI

struct WelcomeView: View {
    let onGetStarted: () -> Void

    var body: some View {
        ZStack {
            LinearGradient.emberDeep.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Brand mark
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 140, height: 140)
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 20)

                Text("FlareFit")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Your voice-coached workout timer")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 4)

                Spacer()

                VStack(alignment: .leading, spacing: 22) {
                    featureRow(icon: "timer",
                               title: "Plans that run themselves",
                               subtitle: "Reps, rounds, rest and switch timers — hands off.")
                    featureRow(icon: "waveform",
                               title: "A coach in your ear",
                               subtitle: "Voice cues in English or German, ticks for every countdown.")
                    featureRow(icon: "music.note",
                               title: "Music & Siri built in",
                               subtitle: "Your music plays underneath. Say “Hey Siri, start my workout in FlareFit.”")
                }
                .padding(.horizontal, 28)

                Spacer()

                Text("FlareFit is not a medical app. Consult a professional before starting a new exercise program, and stop if you feel pain. By continuing you accept the Terms of Use.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 14)

                Button(action: onGetStarted) {
                    Text("Get Started")
                        .font(.title3.bold())
                        .foregroundStyle(Color(red: 0.85, green: 0.16, blue: 0.05))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: Capsule())
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}

#Preview {
    WelcomeView {}
}
