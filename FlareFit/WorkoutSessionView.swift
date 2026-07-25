//
//  WorkoutSessionView.swift
//  FlareFit
//
//  Visual hierarchy (top → bottom): what you're doing now, how long is left
//  in this step, what's next, then session-level progress anchored above
//  the controls. The background color carries the phase.
//

import SwiftUI

struct WorkoutSessionView: View {
    @ObservedObject var engine: WorkoutEngine
    @StateObject private var music = MusicManager.shared
    @AppStorage("autoPlayMusic") private var autoPlayMusic = false

    var body: some View {
        ZStack {
            phaseColor.ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: phaseColor)

            VStack(spacing: 24) {
                header

                Spacer()

                heroSection

                timerRing

                nextUpSection

                Spacer()

                if !engine.isFinished {
                    overallProgressBar
                }

                controls
            }
            .padding()
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if autoPlayMusic {
                MusicManager.shared.startWorkoutMusic()
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(engine.currentStep?.progressText ?? "")
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Button {
                if music.isPlaying {
                    music.togglePlayPause()
                } else {
                    music.startWorkoutMusic()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "music.note")
                    Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white.opacity(0.2), in: Capsule())
            }
            Button {
                WorkoutCoordinator.shared.endWorkout()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Hero: what you're doing right now

    @ViewBuilder
    private var heroSection: some View {
        VStack(spacing: 8) {
            if engine.isFinished {
                Text("DONE")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            } else if let step = engine.currentStep {
                if step.kind == .work {
                    Text("WORK")
                        .font(.caption.bold())
                        .tracking(2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.25), in: Capsule())
                    Text(step.title)
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if !step.detail.isEmpty {
                        Text(step.detail)
                            .font(.title3.bold())
                            .foregroundStyle(.white.opacity(0.85))
                    }
                } else {
                    Text(phaseTitle)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: engine.stepIndex)
        .frame(minHeight: 110)
    }

    // MARK: - Step countdown

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.25), lineWidth: 14)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(.white, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: ringProgress)
            Text("\(max(engine.secondsRemaining, 0))")
                .font(.system(size: 92, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(width: 250, height: 250)
    }

    // MARK: - Next up

    @ViewBuilder
    private var nextUpSection: some View {
        Group {
            if engine.isFinished {
                Text("🎉 Great job!")
                    .font(.title.bold())
                    .foregroundStyle(.white)
            } else if let step = engine.currentStep, let next = step.nextName {
                HStack(spacing: 6) {
                    Text("Next:")
                        .foregroundStyle(.white.opacity(0.6))
                    Text(next)
                        .bold()
                        .foregroundStyle(.white.opacity(0.95))
                }
                .font(.title3)
            }
        }
        .frame(minHeight: 32)
    }

    // MARK: - Session progress (anchored above the controls)

    private var overallProgressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.25))
                    Capsule()
                        .fill(.white)
                        .frame(width: max(geo.size.width * engine.overallProgress, 10))
                        .animation(.linear(duration: 1), value: engine.overallProgress)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(Int((engine.overallProgress * 100).rounded()))%")
                Spacer()
                Text(totalRemainingText)
            }
            .font(.footnote.bold())
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 4)
    }

    private var totalRemainingText: String {
        let total = engine.totalSecondsRemaining
        return String(format: "%d:%02d left", total / 60, total % 60)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 20) {
            if engine.isFinished {
                Button {
                    WorkoutCoordinator.shared.endWorkout()
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.25))
            } else {
                Button {
                    engine.togglePause()
                } label: {
                    Label(engine.isPaused ? "Resume" : "Pause",
                          systemImage: engine.isPaused ? "play.fill" : "pause.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.25))

                Button {
                    engine.skip()
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.25))
            }
        }
        .foregroundStyle(.white)
    }

    // MARK: - Phase styling

    private var phaseTitle: String {
        if engine.isFinished { return "DONE" }
        switch engine.currentStep?.kind {
        case .getReady: return "GET READY"
        case .work: return "WORK"
        case .rest: return "REST"
        case .switching: return "SWITCH"
        case nil: return ""
        }
    }

    private var phaseColor: Color {
        if engine.isFinished { return Color(red: 0.15, green: 0.6, blue: 0.3) }
        switch engine.currentStep?.kind {
        case .getReady, nil: return Color(red: 0.2, green: 0.3, blue: 0.6)
        case .work: return Color(red: 0.9, green: 0.35, blue: 0.15)
        case .rest: return Color(red: 0.1, green: 0.55, blue: 0.55)
        case .switching: return Color(red: 0.45, green: 0.3, blue: 0.7)
        }
    }

    private var ringProgress: CGFloat {
        CGFloat(max(engine.secondsRemaining, 0)) / CGFloat(engine.phaseDuration)
    }
}

#Preview {
    WorkoutSessionView(engine: WorkoutEngine(plan: .sample, coach: SpeechCoach()))
}
