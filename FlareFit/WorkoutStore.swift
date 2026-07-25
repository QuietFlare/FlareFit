import Foundation

@MainActor
final class WorkoutStore: ObservableObject {
    static let shared = WorkoutStore()

    @Published var plans: [WorkoutPlan] {
        didSet { save() }
    }

    private static let storageKey = "flarefit.plans.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([WorkoutPlan].self, from: data) {
            plans = saved
        } else {
            plans = [.sample]
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(plans) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        ReminderScheduler.sync(plans: plans)
    }
}
