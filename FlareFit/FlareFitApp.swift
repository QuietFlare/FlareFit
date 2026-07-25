//
//  FlareFitApp.swift
//  FlareFit
//
//  Created by Seema Jagadeesh on 23.07.26.
//

import SwiftUI

@main
struct FlareFitApp: App {
    @StateObject private var store = WorkoutStore.shared

    init() {
        // Clear any Live Activity left behind by a force-killed session.
        Task { @MainActor in
            LiveActivityManager.shared.cleanupOrphans()
        }

        #if DEBUG
        // Headless testing hook: `simctl launch ... -autostartWorkout` starts a
        // short deterministic workout so Live Activity behavior can be observed
        // without UI interaction. Debug builds only.
        if ProcessInfo.processInfo.arguments.contains("-autostartWorkout") {
            let plan = WorkoutPlan(
                name: "Full Body",
                repetitions: 1,
                switchSeconds: 10,
                exercises: [
                    Exercise(name: "Jumping Jacks", repetitions: 2, workSeconds: 40, restSeconds: 15),
                    Exercise(name: "Squats", repetitions: 3, workSeconds: 45, restSeconds: 20),
                ]
            )
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                WorkoutCoordinator.shared.startWorkout(plan: plan)
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
