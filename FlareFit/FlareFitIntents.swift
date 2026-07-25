//
//  FlareFitIntents.swift
//  FlareFit
//
//  Siri & Shortcuts integration. Say e.g. "Hey Siri, start my workout in FlareFit".
//  In-workout controls return silently — Siri dismisses right away and the
//  coach voice confirms the action in-app.
//

import AppIntents

enum FlareFitIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case noActiveWorkout
    case noPlans

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noActiveWorkout:
            return "No workout is running."
        case .noPlans:
            return "You don't have any workout plans yet. Create one in FlareFit first."
        }
    }
}

struct StartWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Workout"
    static var description = IntentDescription("Starts your most recently used workout plan.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let plan = WorkoutCoordinator.shared.defaultPlan(from: WorkoutStore.shared.plans) else {
            throw FlareFitIntentError.noPlans
        }
        WorkoutCoordinator.shared.startWorkout(plan: plan)
        return .result(dialog: "Starting \(plan.name). Let's go!")
    }
}

struct PauseResumeWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause or Resume Workout"
    static var description = IntentDescription("Pauses the workout if running, resumes it if paused.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let engine = WorkoutCoordinator.shared.activeEngine, !engine.isFinished else {
            throw FlareFitIntentError.noActiveWorkout
        }
        engine.togglePause()  // coach announces "Paused." / "Resumed."
        return .result()
    }
}

struct SkipExerciseIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip"
    static var description = IntentDescription("Skips the current timer step in the workout.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let engine = WorkoutCoordinator.shared.activeEngine, !engine.isFinished else {
            throw FlareFitIntentError.noActiveWorkout
        }
        engine.skip()  // coach announces the next step
        return .result()
    }
}

struct EndWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "End Workout"
    static var description = IntentDescription("Ends the current workout.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        guard WorkoutCoordinator.shared.isWorkoutActive else {
            throw FlareFitIntentError.noActiveWorkout
        }
        WorkoutCoordinator.shared.endWorkout()
        return .result()
    }
}

struct PlayMusicIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Workout Music"
    static var description = IntentDescription("Starts your chosen workout music.")

    @MainActor
    func perform() async throws -> some IntentResult {
        MusicManager.shared.startWorkoutMusic()
        return .result()
    }
}

struct PauseMusicIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Workout Music"
    static var description = IntentDescription("Pauses the workout music.")

    @MainActor
    func perform() async throws -> some IntentResult {
        MusicManager.shared.pauseMusic()
        return .result()
    }
}

struct FlareFitShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start my workout in \(.applicationName)",
                "Start workout in \(.applicationName)",
                "Begin my workout in \(.applicationName)",
            ],
            shortTitle: "Start Workout",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: PauseResumeWorkoutIntent(),
            phrases: [
                "Pause my workout in \(.applicationName)",
                "Pause \(.applicationName)",
                "Resume my workout in \(.applicationName)",
                "Resume \(.applicationName)",
            ],
            shortTitle: "Pause / Resume",
            systemImageName: "pause.fill"
        )
        AppShortcut(
            intent: SkipExerciseIntent(),
            phrases: [
                "Skip exercise in \(.applicationName)",
                "Skip in \(.applicationName)",
            ],
            shortTitle: "Skip",
            systemImageName: "forward.fill"
        )
        AppShortcut(
            intent: EndWorkoutIntent(),
            phrases: [
                "End my workout in \(.applicationName)",
                "Stop my workout in \(.applicationName)",
            ],
            shortTitle: "End Workout",
            systemImageName: "stop.fill"
        )
        AppShortcut(
            intent: PlayMusicIntent(),
            phrases: [
                "Play music in \(.applicationName)",
            ],
            shortTitle: "Play Music",
            systemImageName: "music.note"
        )
        AppShortcut(
            intent: PauseMusicIntent(),
            phrases: [
                "Pause music in \(.applicationName)",
            ],
            shortTitle: "Pause Music",
            systemImageName: "pause.circle"
        )
    }
}
