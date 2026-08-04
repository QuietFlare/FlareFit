//
//  WorkoutCoordinator.swift
//  FlareFit
//
//  App-level owner of the active workout session. Both the UI and Siri
//  (App Intents) drive workouts through this single object.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
final class WorkoutCoordinator: ObservableObject {
    static let shared = WorkoutCoordinator()
    private static let lastPlanKey = "lastUsedPlanID"

    @Published var activeEngine: WorkoutEngine?
    private var sessionStart: Date?

    private init() {}

    var isWorkoutActive: Bool { activeEngine != nil }

    func startWorkout(plan: WorkoutPlan) {
        endWorkout()  // logs any session already in progress
        BackgroundAudioKeeper.shared.start()   // configure the audio session for coach + music
        UIApplication.shared.isIdleTimerDisabled = true  // keep the screen awake during the workout
        if FeatureFlags.liveActivityEnabled {
            LiveActivityManager.shared.start(planName: plan.name)
        }
        let engine = WorkoutEngine(plan: plan, coach: SpeechCoach())
        activeEngine = engine
        sessionStart = Date()
        UserDefaults.standard.set(plan.id.uuidString, forKey: Self.lastPlanKey)
        engine.start()
    }

    func endWorkout() {
        if let engine = activeEngine, let start = sessionStart {
            let duration = Int(Date().timeIntervalSince(start))
            let completed = engine.isFinished  // capture before end() forces it true
            if completed || duration >= 30 {
                HistoryStore.shared.record(WorkoutLogEntry(
                    planID: engine.plan.id,
                    planName: engine.plan.name,
                    date: start,
                    durationSeconds: duration,
                    completed: completed,
                    exercisesCount: engine.plan.exercises.count
                ))
            }
        }
        sessionStart = nil
        activeEngine?.end()
        activeEngine = nil
        BackgroundAudioKeeper.shared.stop()
        UIApplication.shared.isIdleTimerDisabled = false  // let the screen sleep normally again
        LiveActivityManager.shared.end()
    }

    /// The plan Siri starts when none is named: most recently used, else the first.
    func defaultPlan(from plans: [WorkoutPlan]) -> WorkoutPlan? {
        if let id = UserDefaults.standard.string(forKey: Self.lastPlanKey),
           let uuid = UUID(uuidString: id),
           let plan = plans.first(where: { $0.id == uuid }) {
            return plan
        }
        return plans.first
    }
}
