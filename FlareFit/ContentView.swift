//
//  ContentView.swift
//  FlareFit
//

import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator = WorkoutCoordinator.shared
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some View {
        TabView {
            PlansView()
                .tabItem { Label("Plans", systemImage: "dumbbell.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenWelcome },
            set: { _ in }
        )) {
            WelcomeView {
                hasSeenWelcome = true
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { coordinator.activeEngine != nil },
            set: { if !$0 { coordinator.endWorkout() } }
        )) {
            if let engine = coordinator.activeEngine {
                WorkoutSessionView(engine: engine)
            }
        }
    }
}

struct PlansView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var showingNewPlanAlert = false
    @State private var newPlanName = ""
    @State private var showingAIImport = false
    @State private var showingSettings = false
    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            List {
                ForEach($store.plans) { $plan in
                    NavigationLink {
                        PlanDetailView(plan: $plan)
                    } label: {
                        PlanRow(plan: plan)
                    }
                }
                .onDelete { store.plans.remove(atOffsets: $0) }
                .onMove { store.plans.move(fromOffsets: $0, toOffset: $1) }
            }
            .navigationTitle("FlareFit")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAbout = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            newPlanName = ""
                            showingNewPlanAlert = true
                        } label: {
                            Label("New Plan", systemImage: "square.and.pencil")
                        }
                        if FeatureFlags.aiFeaturesEnabled {
                            Button {
                                showingAIImport = true
                            } label: {
                                Label("Create from Photo (AI)", systemImage: "sparkles")
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Plan", isPresented: $showingNewPlanAlert) {
                TextField("Name (e.g. Arms)", text: $newPlanName)
                Button("Create") {
                    let name = newPlanName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    store.plans.append(
                        WorkoutPlan(name: name, repetitions: 1, switchSeconds: 10, exercises: [])
                    )
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Name this workout session.")
            }
            .sheet(isPresented: $showingAIImport) {
                ImportPlanView { newPlan in
                    store.plans.append(newPlan)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .overlay {
                if store.plans.isEmpty {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient.ember)
                                .frame(width: 88, height: 88)
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
                        }
                        Text("Let's build your first plan")
                            .font(.title2.bold())
                        Text("A plan is a session like \"Arms\" or \"Full Body\" —\nexercises with reps, work and rest timers.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button {
                            newPlanName = ""
                            showingNewPlanAlert = true
                        } label: {
                            Label("Create a Plan", systemImage: "plus")
                                .font(.headline)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
        }
    }
}

struct PlanRow: View {
    let plan: WorkoutPlan

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient.ember)
                    .frame(width: 48, height: 48)
                Image(systemName: "dumbbell.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name)
                    .font(.headline)
                HStack(spacing: 12) {
                    Label("\(plan.exercises.count) exercises", systemImage: "list.bullet")
                    if plan.repetitions > 1 {
                        Label("\(plan.repetitions)× rounds", systemImage: "repeat")
                    }
                    Label(durationText, systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var durationText: String {
        let total = WorkoutEngine.totalSeconds(for: plan)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct PlanDetailView: View {
    @Binding var plan: WorkoutPlan
    @StateObject private var music = MusicManager.shared
    @State private var editingExercise: Exercise?
    @State private var showingNewExercise = false
    @State private var showingMusicPicker = false
    @AppStorage("autoPlayMusic") private var autoPlayMusic = false

    var body: some View {
        List {
            Section {
                TextField("Plan name", text: $plan.name)
                    .font(.headline)
                Stepper("Plan repeats: \(plan.repetitions)×",
                        value: $plan.repetitions, in: 1...10)
                HStack {
                    Label("Switch timer", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    Text("\(plan.switchSeconds)s")
                        .foregroundStyle(.secondary)
                    Stepper("", value: $plan.switchSeconds, in: 0...60, step: 5)
                        .labelsHidden()
                }
            } header: {
                Text("Plan settings")
            } footer: {
                Text("Plan repeats runs the whole session again. The switch timer is the countdown between exercises.")
            }

            Section("Exercises") {
                ForEach(plan.exercises) { exercise in
                    Button {
                        editingExercise = exercise
                    } label: {
                        ExerciseRow(exercise: exercise)
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete { plan.exercises.remove(atOffsets: $0) }
                .onMove { plan.exercises.move(fromOffsets: $0, toOffset: $1) }

                Button {
                    showingNewExercise = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                }
            }

            scheduleSection

            Section {
                Button {
                    showingMusicPicker = true
                } label: {
                    Label("Choose Workout Music", systemImage: "music.note.list")
                }
                if let title = music.nowPlayingTitle {
                    HStack {
                        Label(title, systemImage: "music.note")
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            music.togglePlayPause()
                        } label: {
                            Image(systemName: music.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title2)
                        }
                    }
                }
                Toggle("Start music with workout", isOn: $autoPlayMusic)
            } header: {
                Text("Music")
            } footer: {
                Text("Use the music button on the workout screen to start or pause anytime. Prefer Spotify or another app? Just start your music there — the voice coach automatically lowers it while speaking.")
            }

            Section {
                Text("Total: \(totalDurationText)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                WorkoutCoordinator.shared.startWorkout(plan: plan)
            } label: {
                Label("Start Workout", systemImage: "play.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(plan.exercises.isEmpty)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showingMusicPicker) {
            MusicPicker()
                .ignoresSafeArea()
        }
        .task(id: plan) {
            // Pre-generate natural voice clips for this plan while the user
            // is still looking at it, so the workout plays them instantly.
            guard FeatureFlags.aiFeaturesEnabled else { return }
            await ElevenLabsVoice.shared.prepare(phrases: WorkoutEngine.allAnnouncements(for: plan))
        }
        .sheet(item: $editingExercise) { exercise in
            ExerciseEditView(exercise: exercise) { updated in
                if let index = plan.exercises.firstIndex(where: { $0.id == updated.id }) {
                    plan.exercises[index] = updated
                }
            }
        }
        .sheet(isPresented: $showingNewExercise) {
            ExerciseEditView(exercise: Exercise(name: "", repetitions: 3, workSeconds: 30, restSeconds: 15)) { new in
                plan.exercises.append(new)
            }
        }
    }

    private var totalDurationText: String {
        let total = WorkoutEngine.totalSeconds(for: plan)
        return String(format: "%d min %02d sec", total / 60, total % 60)
    }

    // MARK: - Schedule / reminders

    private var scheduleSection: some View {
        Section {
            Toggle("Remind me", isOn: reminderEnabledBinding)
            if plan.reminder?.enabled == true {
                DatePicker("Starts at", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                WeekdayPicker(weekdays: reminderWeekdaysBinding)
                Picker("Notify", selection: reminderLeadBinding) {
                    Text("At start time").tag(0)
                    Text("5 min before").tag(5)
                    Text("10 min before").tag(10)
                    Text("15 min before").tag(15)
                    Text("30 min before").tag(30)
                }
            }
        } header: {
            Text("Schedule")
        } footer: {
            if plan.reminder?.enabled == true && (plan.reminder?.weekdays.isEmpty ?? true) {
                Text("Pick at least one day to get reminders.")
            }
        }
    }

    private var reminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { plan.reminder?.enabled ?? false },
            set: { on in
                var reminder = plan.reminder ?? PlanReminder()
                reminder.enabled = on
                plan.reminder = reminder
                if on {
                    Task { _ = await ReminderScheduler.requestAuthorization() }
                }
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                let reminder = plan.reminder ?? PlanReminder()
                return Calendar.current.date(
                    from: DateComponents(hour: reminder.hour, minute: reminder.minute)
                ) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                var reminder = plan.reminder ?? PlanReminder()
                reminder.hour = components.hour ?? 18
                reminder.minute = components.minute ?? 0
                plan.reminder = reminder
            }
        )
    }

    private var reminderWeekdaysBinding: Binding<Set<Int>> {
        Binding(
            get: { plan.reminder?.weekdays ?? [] },
            set: { days in
                var reminder = plan.reminder ?? PlanReminder()
                reminder.weekdays = days
                plan.reminder = reminder
            }
        )
    }

    private var reminderLeadBinding: Binding<Int> {
        Binding(
            get: { plan.reminder?.leadMinutes ?? 10 },
            set: { lead in
                var reminder = plan.reminder ?? PlanReminder()
                reminder.leadMinutes = lead
                plan.reminder = reminder
            }
        )
    }
}

/// Seven tappable circles, one per weekday (Calendar numbering: 1 = Sunday).
struct WeekdayPicker: View {
    @Binding var weekdays: Set<Int>
    private let symbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1..<8) { day in
                let selected = weekdays.contains(day)
                Button {
                    if selected {
                        weekdays.remove(day)
                    } else {
                        weekdays.insert(day)
                    }
                } label: {
                    Text(symbols[day - 1])
                        .font(.subheadline.bold())
                        .frame(width: 36, height: 36)
                        .background(
                            selected ? AnyShapeStyle(LinearGradient.ember) : AnyShapeStyle(Color(.systemGray5)),
                            in: Circle()
                        )
                        .foregroundStyle(selected ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.headline)
            HStack(spacing: 12) {
                Label("\(exercise.repetitions)×", systemImage: "repeat")
                Label("\(exercise.workSeconds)s work", systemImage: "flame")
                Label("\(exercise.restSeconds)s rest", systemImage: "pause.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct ExerciseEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State var exercise: Exercise
    let onSave: (Exercise) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Name (e.g. Push-ups)", text: $exercise.name)
                }
                Section {
                    Stepper("Repetitions: \(exercise.repetitions)×",
                            value: $exercise.repetitions, in: 1...20)
                    Stepper("Work: \(exercise.workSeconds)s",
                            value: $exercise.workSeconds, in: 5...600, step: 5)
                    Stepper("Rest: \(exercise.restSeconds)s",
                            value: $exercise.restSeconds, in: 0...300, step: 5)
                } header: {
                    Text("Repetitions & Timers")
                } footer: {
                    Text("Each repetition runs the work timer, then the rest timer.")
                }
            }
            .navigationTitle(exercise.name.isEmpty ? "New Exercise" : exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(exercise)
                        dismiss()
                    }
                    .disabled(exercise.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WorkoutStore())
}
