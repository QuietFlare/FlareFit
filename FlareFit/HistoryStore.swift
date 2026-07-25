//
//  HistoryStore.swift
//  FlareFit
//

import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var entries: [WorkoutLogEntry]

    private static let storageKey = "flarefit.history.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([WorkoutLogEntry].self, from: data) {
            entries = saved
        } else {
            entries = []
        }
    }

    func record(_ entry: WorkoutLogEntry) {
        entries.insert(entry, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    /// Sessions started in the current calendar week.
    var thisWeek: [WorkoutLogEntry] {
        entries.filter {
            Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .weekOfYear)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
