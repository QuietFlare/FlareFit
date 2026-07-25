//
//  HistoryView.swift
//  FlareFit
//

import SwiftUI

struct HistoryView: View {
    @StateObject private var history = HistoryStore.shared

    var body: some View {
        NavigationStack {
            List {
                if !history.entries.isEmpty {
                    summarySection
                    Section("Workouts") {
                        ForEach(history.entries) { entry in
                            HistoryRow(entry: entry)
                        }
                        .onDelete { history.delete(at: $0) }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !history.entries.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) { EditButton() }
                }
            }
            .overlay {
                if history.entries.isEmpty {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient.ember)
                                .frame(width: 88, height: 88)
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 38))
                                .foregroundStyle(.white)
                        }
                        Text("No workouts yet")
                            .font(.title2.bold())
                        Text("Finish your first workout and it will show up here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
        }
    }

    private var summarySection: some View {
        Section {
            HStack(spacing: 0) {
                stat(value: "\(history.thisWeek.count)", label: "this week")
                Divider().padding(.vertical, 4)
                stat(value: minutesText(history.thisWeek.reduce(0) { $0 + $1.durationSeconds }),
                     label: "this week")
                Divider().padding(.vertical, 4)
                stat(value: "\(history.entries.count)", label: "all time")
            }
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(LinearGradient.ember)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func minutesText(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds)s" : "\(seconds / 60) min"
    }
}

struct HistoryRow: View {
    let entry: WorkoutLogEntry

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(entry.completed ? AnyShapeStyle(LinearGradient.ember) : AnyShapeStyle(Color(.systemGray4)))
                    .frame(width: 40, height: 40)
                Image(systemName: entry.completed ? "checkmark" : "flag.slash")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.planName)
                    .font(.headline)
                Text(entry.date, format: .dateTime.weekday(.abbreviated).day().month().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(durationText)
                    .font(.subheadline.bold())
                    .monospacedDigit()
                Text(entry.completed ? "Completed" : "Ended early")
                    .font(.caption2)
                    .foregroundStyle(entry.completed ? .green : .secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var durationText: String {
        let minutes = entry.durationSeconds / 60
        let seconds = entry.durationSeconds % 60
        return minutes > 0 ? "\(minutes):\(String(format: "%02d", seconds))" : "0:\(String(format: "%02d", seconds))"
    }
}

#Preview {
    HistoryView()
}
