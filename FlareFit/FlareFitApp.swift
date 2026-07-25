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
                name: "Debug",
                repetitions: 1,
                switchSeconds: 3,
                exercises: [
                    Exercise(name: "Alpha", repetitions: 2, workSeconds: 5, restSeconds: 3),
                    Exercise(name: "Beta", repetitions: 1, workSeconds: 5, restSeconds: 0),
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
