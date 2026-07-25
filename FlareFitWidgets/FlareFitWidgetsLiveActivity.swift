//
//  FlareFitWidgetsLiveActivity.swift
//  FlareFitWidgets
//
//  The lock-screen / Dynamic Island workout card. The countdown is rendered
//  by the system (Text(timerInterval:)), so it keeps ticking even while the
//  app itself is suspended (e.g. during a phone call).
//

import ActivityKit
import WidgetKit
import SwiftUI

// Duplicate of the declaration in the app target (LiveActivityManager.swift).
// ActivityKit matches them by type name and Codable shape — keep in sync.
struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var phaseTitle: String
        var phaseKey: String       // "getReady" | "work" | "rest" | "switching" | "done"
        var detail: String
        var progressText: String
        var endDate: Date           // end of the current step
        var workoutStartDate: Date  // when the workout began
        var workoutEndDate: Date    // projected end of the whole workout
        var paused: Bool
    }

    var planName: String
}

struct FlareFitWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenCard(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(context.attributes.planName, systemImage: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text(context.state.phaseTitle)
                            .font(.title3.bold())
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerView(context.state, font: .title2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if !context.state.detail.isEmpty {
                            Text(context.state.detail)
                        }
                        Spacer()
                        if !context.state.paused {
                            HStack(spacing: 3) {
                                Image(systemName: "hourglass")
                                Text(timerInterval: Date.now...max(context.state.workoutEndDate, Date.now),
                                     countsDown: true)
                                    .monospacedDigit()
                                    .frame(maxWidth: 52)
                            }
                        }
                        Spacer()
                        Text(context.state.progressText)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: phaseSymbol(context.state))
                    .foregroundStyle(.orange)
            } compactTrailing: {
                timerView(context.state, font: .caption2)
                    .frame(maxWidth: 46)
            } minimal: {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private func timerView(_ state: WorkoutActivityAttributes.ContentState, font: Font) -> some View {
        if state.paused {
            Text("Paused")
                .font(font.bold())
                .foregroundStyle(.secondary)
        } else {
            Text(timerInterval: Date.now...max(state.endDate, Date.now), countsDown: true)
                .font(font.bold())
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
    }

    private func phaseSymbol(_ state: WorkoutActivityAttributes.ContentState) -> String {
        switch state.phaseKey {
        case "work": return "flame.fill"
        case "rest": return "pause.circle.fill"
        case "switching": return "arrow.triangle.2.circlepath"
        case "done": return "checkmark.circle.fill"
        default: return "timer"
        }
    }
}

private struct LockScreenCard: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            cardContent
            if !progressBarHidden {
                // Static bar, refreshed on every phase update. (The self-animating
                // ProgressView(timerInterval:) stalls Live Activity updates on
                // iOS 18 — known issue — so we render progress ourselves.)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule().fill(.white)
                            .frame(width: max(geo.size.width * progressFraction, 6))
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .activityBackgroundTint(backgroundColor)
        .activitySystemActionForegroundColor(.white)
    }

    private var cardContent: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 52, height: 52)
                Image(systemName: symbol)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.planName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                Text(context.state.phaseTitle)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                if !context.state.detail.isEmpty || !context.state.progressText.isEmpty {
                    Text(context.state.detail.isEmpty
                         ? context.state.progressText
                         : "\(context.state.detail) · \(context.state.progressText)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if context.state.paused {
                    Text("Paused")
                        .font(.title3.bold())
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    Text(timerInterval: Date.now...max(context.state.endDate, Date.now), countsDown: true)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(maxWidth: 96)
                        .multilineTextAlignment(.trailing)
                    HStack(spacing: 3) {
                        Image(systemName: "hourglass")
                            .font(.caption2)
                        Text(timerInterval: Date.now...max(context.state.workoutEndDate, Date.now),
                             countsDown: true)
                            .font(.caption.bold())
                            .monospacedDigit()
                            .frame(maxWidth: 52)
                    }
                    .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
    }

    private var progressBarHidden: Bool {
        context.state.paused || context.state.phaseKey == "done"
    }

    /// Workout progress as of this update (re-rendered on every phase change).
    private var progressFraction: Double {
        let total = context.state.workoutEndDate.timeIntervalSince(context.state.workoutStartDate)
        guard total > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince(context.state.workoutStartDate)
        return min(max(elapsed / total, 0), 1)
    }

    private var symbol: String {
        switch context.state.phaseKey {
        case "work": return "flame.fill"
        case "rest": return "pause.circle.fill"
        case "switching": return "arrow.triangle.2.circlepath"
        case "done": return "checkmark.circle.fill"
        default: return "timer"
        }
    }

    private var backgroundColor: Color {
        switch context.state.phaseKey {
        case "work": return Color(red: 0.90, green: 0.35, blue: 0.15)
        case "rest": return Color(red: 0.10, green: 0.55, blue: 0.55)
        case "switching": return Color(red: 0.45, green: 0.30, blue: 0.70)
        case "done": return Color(red: 0.15, green: 0.60, blue: 0.30)
        default: return Color(red: 0.20, green: 0.30, blue: 0.60)
        }
    }
}
