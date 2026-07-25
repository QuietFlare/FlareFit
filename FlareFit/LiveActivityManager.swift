//
//  LiveActivityManager.swift
//  FlareFit
//
//  Drives the lock-screen / Dynamic Island workout card. The system renders
//  the countdown itself (Text(timerInterval:)), so the card keeps counting
//  even while the app is suspended — phone calls included.
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Shared with the FlareFitWidgets extension — keep both copies identical.
#if canImport(ActivityKit)
struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var phaseTitle: String
        var phaseKey: String       // "getReady" | "work" | "rest" | "switching"
        var detail: String         // e.g. "Rep 2 of 3"
        var progressText: String   // e.g. "Exercise 1 of 5"
        var endDate: Date           // end of the current step
        var workoutStartDate: Date  // when the workout began
        var workoutEndDate: Date    // projected end of the whole workout
        var paused: Bool
    }

    var planName: String
}
#endif

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    #if canImport(ActivityKit)
    private var activity: Activity<WorkoutActivityAttributes>?
    #endif

    private init() {}

    /// Ends any leftover activities from crashed / force-killed sessions.
    /// Called at app launch — iOS keeps orphaned cards for up to 8 hours
    /// otherwise, since a killed app never gets a chance to clean up.
    func cleanupOrphans() {
        #if canImport(ActivityKit)
        guard activity == nil else { return }  // an actual workout is running
        for orphan in Activity<WorkoutActivityAttributes>.activities {
            Task { await orphan.end(nil, dismissalPolicy: .immediate) }
        }
        #endif
    }

    func start(planName: String) {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()
        // Kill any zombie activities left over from crashed/killed sessions —
        // they linger for hours with self-animating timers and look "frozen".
        for stale in Activity<WorkoutActivityAttributes>.activities {
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }
        let attributes = WorkoutActivityAttributes(planName: planName)
        let state = WorkoutActivityAttributes.ContentState(
            phaseTitle: "Get Ready",
            phaseKey: "getReady",
            detail: "",
            progressText: "",
            endDate: Date().addingTimeInterval(5),
            workoutStartDate: Date(),
            workoutEndDate: Date().addingTimeInterval(5),
            paused: false
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            // Live Activity is best-effort — the in-app timer is the source of truth.
        }
        #endif
    }

    func update(phaseTitle: String, phaseKey: String, detail: String,
                progressText: String, endDate: Date, workoutStartDate: Date,
                workoutEndDate: Date, paused: Bool) {
        #if canImport(ActivityKit)
        guard let activity else { return }
        let state = WorkoutActivityAttributes.ContentState(
            phaseTitle: phaseTitle,
            phaseKey: phaseKey,
            detail: detail,
            progressText: progressText,
            endDate: endDate,
            workoutStartDate: workoutStartDate,
            workoutEndDate: workoutEndDate,
            paused: paused
        )
        Task {
            // staleDate: if the app dies and updates stop, iOS dims the card
            // shortly after the step it shows should have ended.
            await activity.update(.init(state: state, staleDate: endDate.addingTimeInterval(30)))
        }
        #endif
    }

    /// Shows "Done" briefly, then removes the card.
    func finish() {
        #if canImport(ActivityKit)
        guard let activity else { return }
        let state = WorkoutActivityAttributes.ContentState(
            phaseTitle: "Done",
            phaseKey: "done",
            detail: "",
            progressText: "",
            endDate: Date(),
            workoutStartDate: Date(),
            workoutEndDate: Date(),
            paused: false
        )
        Task {
            await activity.end(.init(state: state, staleDate: nil),
                               dismissalPolicy: .after(Date().addingTimeInterval(30)))
        }
        self.activity = nil
        #endif
    }

    func end() {
        #if canImport(ActivityKit)
        guard let activity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        self.activity = nil
        #endif
    }
}
