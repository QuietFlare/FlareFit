import Foundation

struct Exercise: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    /// How many times this exercise repeats (each repetition = work timer, then rest timer).
    var repetitions: Int
    var workSeconds: Int
    var restSeconds: Int
}

/// One completed (or abandoned) workout session.
struct WorkoutLogEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var planID: UUID?
    var planName: String
    var date: Date
    var durationSeconds: Int
    var completed: Bool
    var exercisesCount: Int
}

/// Weekly reminder schedule for a plan, delivered as local notifications.
struct PlanReminder: Codable, Equatable {
    var enabled = false
    var hour = 18
    var minute = 0
    /// 1 = Sunday … 7 = Saturday (Calendar weekday numbering).
    var weekdays: Set<Int> = []
    /// Notify this many minutes before the start time (0 = at start time).
    var leadMinutes = 10
}

struct WorkoutPlan: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    /// How many times the whole plan repeats.
    var repetitions: Int
    /// Transition ("switch") timer before the next exercise begins.
    var switchSeconds: Int
    var exercises: [Exercise]
    /// Optional weekly reminder (nil on plans created before this feature).
    var reminder: PlanReminder?

    static let sample = WorkoutPlan(
        name: "Full Body",
        repetitions: 1,
        switchSeconds: 10,
        exercises: [
            Exercise(name: "Jumping Jacks", repetitions: 2, workSeconds: 30, restSeconds: 15),
            Exercise(name: "Push-ups", repetitions: 3, workSeconds: 30, restSeconds: 15),
            Exercise(name: "Squats", repetitions: 3, workSeconds: 40, restSeconds: 20),
            Exercise(name: "Plank", repetitions: 1, workSeconds: 45, restSeconds: 20),
            Exercise(name: "Lunges", repetitions: 2, workSeconds: 40, restSeconds: 15),
        ]
    )
}
