import Foundation
import Combine

enum StepKind: Equatable {
    case getReady
    case work
    case rest
    case switching
}

/// One timed segment of a workout. The whole session is flattened into an ordered
/// list of steps up front, so repetitions of exercises and of the whole plan are
/// just more steps in the sequence.
struct WorkoutStep {
    let kind: StepKind
    let seconds: Int
    let announcement: String
    /// Exercise name shown during work steps.
    let title: String
    /// e.g. "Rep 2 of 3"
    let detail: String
    /// e.g. "Exercise 1 of 5 • Round 1 of 2"
    let progressText: String
    /// Name of the upcoming exercise, for the "Next:" label.
    var nextName: String?
}

@MainActor
final class WorkoutEngine: ObservableObject {
    @Published private(set) var stepIndex = 0
    @Published private(set) var secondsRemaining = 0
    @Published private(set) var isFinished = false
    @Published var isPaused = false

    let plan: WorkoutPlan
    let coach: SpeechCoach
    private(set) var steps: [WorkoutStep]

    private var timer: AnyCancellable?
    /// Wall-clock deadline of the current step. Timing is computed from real
    /// dates, so the workout stays accurate across app suspension (phone
    /// calls, backgrounding) and catches up when the app resumes.
    private var stepEndDate: Date?
    private var pausedRemaining: TimeInterval?
    private var lastCountdownSecond = 0

    init(plan: WorkoutPlan, coach: SpeechCoach) {
        self.plan = plan
        self.coach = coach
        self.steps = Self.buildSteps(for: plan)
    }

    var currentStep: WorkoutStep? {
        steps.indices.contains(stepIndex) ? steps[stepIndex] : nil
    }

    var phaseDuration: Int {
        max(currentStep?.seconds ?? 1, 1)
    }

    /// Seconds left in the entire workout (current step + everything after it).
    var totalSecondsRemaining: Int {
        guard steps.indices.contains(stepIndex) else { return 0 }
        let future = steps[(stepIndex + 1)...].reduce(0) { $0 + $1.seconds }
        return max(secondsRemaining, 0) + future
    }

    /// Overall workout completion, 0.0 → 1.0. Skipping steps jumps it forward.
    var overallProgress: Double {
        let planned = steps.reduce(0) { $0 + $1.seconds }
        guard planned > 0 else { return 0 }
        if isFinished { return 1 }
        return min(max(1.0 - Double(totalSecondsRemaining) / Double(planned), 0), 1)
    }

    /// When the workout actually started — anchors the lock-screen progress bar.
    private var workoutStartDate = Date()

    /// Projected wall-clock end of the whole workout.
    private var workoutEndDate: Date {
        let future = steps[(stepIndex + 1)...].reduce(0) { $0 + $1.seconds }
        return (stepEndDate ?? Date()).addingTimeInterval(TimeInterval(future))
    }

    static func totalSeconds(for plan: WorkoutPlan) -> Int {
        buildSteps(for: plan).reduce(0) { $0 + $1.seconds }
    }

    /// Every line the coach could say during this plan — used to pre-generate
    /// natural voice clips before the workout starts.
    static func allAnnouncements(for plan: WorkoutPlan) -> [String] {
        buildSteps(for: plan).map(\.announcement)
            + ["Workout complete. Well done!", "Paused.", "Resumed."]
    }

    // MARK: - Session control

    func start() {
        guard !steps.isEmpty else {
            isFinished = true
            return
        }
        stepIndex = 0
        workoutStartDate = Date()
        beginCurrentStep()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused {
            pausedRemaining = stepEndDate?.timeIntervalSinceNow
        } else if let remaining = pausedRemaining {
            stepEndDate = Date().addingTimeInterval(max(remaining, 0))
            pausedRemaining = nil
        }
        coach.say(isPaused ? "Paused." : "Resumed.")
        publishLiveActivity()
    }

    func skip() {
        guard !isPaused, !isFinished else { return }
        advance()
    }

    func end() {
        timer?.cancel()
        coach.stop()
        isFinished = true
    }

    // MARK: - Internals

    private func tick() {
        guard !isPaused, !isFinished, let endDate = stepEndDate else { return }
        let remaining = endDate.timeIntervalSinceNow

        if remaining <= 0 {
            catchUp(overshoot: -remaining)
            return
        }

        secondsRemaining = Int(remaining.rounded(.up))
        if secondsRemaining <= 3 && secondsRemaining != lastCountdownSecond {
            lastCountdownSecond = secondsRemaining
            coach.countdownTick(secondsRemaining)
        }
    }

    /// Moves to the step the workout *should* be in, given how much wall time
    /// has passed — one step in the normal case, several if the app was
    /// suspended (e.g. during a phone call).
    private func catchUp(overshoot: TimeInterval) {
        var overshoot = overshoot
        while true {
            guard stepIndex + 1 < steps.count else {
                finish()
                return
            }
            stepIndex += 1
            let stepSeconds = TimeInterval(steps[stepIndex].seconds)
            if overshoot < stepSeconds {
                let remaining = stepSeconds - overshoot
                secondsRemaining = Int(remaining.rounded(.up))
                stepEndDate = Date().addingTimeInterval(remaining)
                lastCountdownSecond = 0
                coach.say(steps[stepIndex].announcement)
                publishLiveActivity()
                return
            }
            overshoot -= stepSeconds
        }
    }

    private func advance() {
        if stepIndex + 1 < steps.count {
            stepIndex += 1
            beginCurrentStep()
        } else {
            finish()
        }
    }

    private func beginCurrentStep() {
        guard let step = currentStep else { return }
        secondsRemaining = step.seconds
        stepEndDate = Date().addingTimeInterval(TimeInterval(step.seconds))
        lastCountdownSecond = 0
        coach.say(step.announcement)
        publishLiveActivity()
    }

    private func finish() {
        timer?.cancel()
        isFinished = true
        coach.say("Workout complete. Well done!")
        LiveActivityManager.shared.finish()
    }

    private func publishLiveActivity() {
        guard let step = currentStep, !isFinished else { return }
        LiveActivityManager.shared.update(
            phaseTitle: Self.phaseTitle(for: step),
            phaseKey: String(describing: step.kind),
            detail: step.detail,
            progressText: step.progressText,
            endDate: stepEndDate ?? Date(),
            workoutStartDate: workoutStartDate,
            workoutEndDate: workoutEndDate,
            paused: isPaused
        )
    }

    /// Lock-screen title for a step — exercise name during work, label otherwise.
    static func phaseTitle(for step: WorkoutStep) -> String {
        switch step.kind {
        case .getReady: return "Get Ready"
        case .work: return step.title
        case .rest: return "Rest"
        case .switching: return "Switch"
        }
    }

    // MARK: - Step building

    static func buildSteps(for plan: WorkoutPlan) -> [WorkoutStep] {
        let exercises = plan.exercises
        guard !exercises.isEmpty else { return [] }

        let rounds = max(plan.repetitions, 1)
        var steps: [WorkoutStep] = []

        steps.append(WorkoutStep(
            kind: .getReady,
            seconds: 5,
            announcement: "Get ready!",
            title: "Get Ready",
            detail: "",
            progressText: "",
            nextName: nil
        ))

        for round in 1...rounds {
            for (index, exercise) in exercises.enumerated() {
                let reps = max(exercise.repetitions, 1)
                let progress = Self.progressText(
                    exercise: index + 1, of: exercises.count,
                    round: round, of: rounds
                )

                for rep in 1...reps {
                    let isLastRep = rep == reps
                    let isVeryEnd = isLastRep && index == exercises.count - 1 && round == rounds

                    let detail = reps > 1 ? "Rep \(rep) of \(reps)" : ""

                    steps.append(WorkoutStep(
                        kind: .work,
                        seconds: exercise.workSeconds,
                        announcement: "Work!",
                        title: exercise.name,
                        detail: detail,
                        progressText: progress,
                        nextName: nil
                    ))

                    if !isLastRep {
                        // Rest only between reps of the same exercise.
                        if exercise.restSeconds > 0 {
                            steps.append(WorkoutStep(
                                kind: .rest,
                                seconds: exercise.restSeconds,
                                announcement: "Rest.",
                                title: exercise.name,
                                detail: detail,
                                progressText: progress,
                                nextName: nil
                            ))
                        }
                    } else if !isVeryEnd {
                        // After the final rep, go straight to the switch timer —
                        // it doubles as the recovery break. If the switch timer is
                        // off, fall back to the rest timer so the transition isn't abrupt.
                        if plan.switchSeconds > 0 {
                            steps.append(WorkoutStep(
                                kind: .switching,
                                seconds: plan.switchSeconds,
                                announcement: "Switch!",
                                title: "Switch",
                                detail: "",
                                progressText: progress,
                                nextName: nil
                            ))
                        } else if exercise.restSeconds > 0 {
                            steps.append(WorkoutStep(
                                kind: .rest,
                                seconds: exercise.restSeconds,
                                announcement: "Rest.",
                                title: exercise.name,
                                detail: detail,
                                progressText: progress,
                                nextName: nil
                            ))
                        }
                    }
                }
            }
        }

        // Back-fill "Next:" labels — each step points at the next upcoming work exercise.
        var upcomingWork: String?
        for index in steps.indices.reversed() {
            steps[index].nextName = upcomingWork
            if steps[index].kind == .work {
                upcomingWork = steps[index].title
            }
        }

        return steps
    }

    private static func progressText(exercise: Int, of exerciseCount: Int,
                                     round: Int, of roundCount: Int) -> String {
        var text = "Exercise \(exercise) of \(exerciseCount)"
        if roundCount > 1 {
            text += " • Round \(round) of \(roundCount)"
        }
        return text
    }
}
