//
//  WorkoutEngineTests.swift
//  FlareFitTests
//
//  Tests for the workout step state machine — the heart of the app.
//

import Foundation
import Testing
@testable import FlareFit

@MainActor
struct WorkoutEngineTests {

    // MARK: - Helpers

    private func exercise(
        name: String = "Push-ups",
        reps: Int = 1,
        work: Int = 30,
        rest: Int = 15
    ) -> Exercise {
        Exercise(name: name, repetitions: reps, workSeconds: work, restSeconds: rest)
    }

    private func plan(
        repetitions: Int = 1,
        switchSeconds: Int = 10,
        exercises: [Exercise]
    ) -> WorkoutPlan {
        WorkoutPlan(name: "Test", repetitions: repetitions, switchSeconds: switchSeconds, exercises: exercises)
    }

    private func kinds(_ plan: WorkoutPlan) -> [StepKind] {
        WorkoutEngine.buildSteps(for: plan).map(\.kind)
    }

    // MARK: - Structure

    @Test func emptyPlanProducesNoSteps() {
        let steps = WorkoutEngine.buildSteps(for: plan(exercises: []))
        #expect(steps.isEmpty)
    }

    @Test func singleExerciseSingleRep() {
        // Get ready, then work — no trailing rest or switch at the very end.
        let p = plan(exercises: [exercise(reps: 1)])
        #expect(kinds(p) == [.getReady, .work])
    }

    @Test func restOnlyBetweenReps() {
        // 3 reps: work-rest-work-rest-work. No rest after the final rep.
        let p = plan(exercises: [exercise(reps: 3)])
        #expect(kinds(p) == [.getReady, .work, .rest, .work, .rest, .work])
    }

    @Test func noRestStepsWhenRestIsZero() {
        let p = plan(exercises: [exercise(reps: 3, rest: 0)])
        #expect(kinds(p) == [.getReady, .work, .work, .work])
    }

    @Test func switchBetweenExercisesNotRest() {
        // After the last rep of an exercise: switch directly, no rest+switch double timer.
        let p = plan(exercises: [exercise(name: "A", reps: 2), exercise(name: "B", reps: 1)])
        #expect(kinds(p) == [.getReady, .work, .rest, .work, .switching, .work])
    }

    @Test func zeroSwitchFallsBackToRest() {
        // switchSeconds == 0: the rest timer bridges exercises instead.
        let p = plan(switchSeconds: 0, exercises: [exercise(name: "A"), exercise(name: "B")])
        #expect(kinds(p) == [.getReady, .work, .rest, .work])
    }

    @Test func zeroSwitchAndZeroRestGoesStraightToNextExercise() {
        let p = plan(switchSeconds: 0, exercises: [exercise(name: "A", rest: 0), exercise(name: "B")])
        #expect(kinds(p) == [.getReady, .work, .work])
    }

    @Test func planRepetitionsRepeatTheWholeSequence() {
        // 2 rounds of a single 1-rep exercise: switch bridges the rounds.
        let p = plan(repetitions: 2, exercises: [exercise(reps: 1)])
        #expect(kinds(p) == [.getReady, .work, .switching, .work])
    }

    @Test func veryEndNeverHasTrailingTimers() {
        let p = plan(repetitions: 3, exercises: [exercise(reps: 4), exercise(name: "B", reps: 2)])
        let steps = WorkoutEngine.buildSteps(for: p)
        #expect(steps.last?.kind == .work)
    }

    // MARK: - Durations

    @Test func totalSecondsMatchesStepSum() {
        let p = plan(repetitions: 2, exercises: [exercise(reps: 2), exercise(name: "B")])
        let sum = WorkoutEngine.buildSteps(for: p).reduce(0) { $0 + $1.seconds }
        #expect(WorkoutEngine.totalSeconds(for: p) == sum)
    }

    @Test func stepDurationsComeFromThePlan() {
        let p = plan(exercises: [exercise(reps: 2, work: 45, rest: 20)])
        let steps = WorkoutEngine.buildSteps(for: p)
        #expect(steps[0].seconds == 5)   // get ready
        #expect(steps[1].seconds == 45)  // work
        #expect(steps[2].seconds == 20)  // rest
        #expect(steps[3].seconds == 45)  // work
    }

    // MARK: - Announcements & labels

    @Test func announcementsAreOnlyFixedPhrases() {
        // The coach only ever says phrases that have bundled voice clips.
        let known: Set<String> = ["Get ready!", "Work!", "Rest.", "Switch!"]
        let p = plan(repetitions: 2, exercises: [exercise(reps: 3), exercise(name: "B", reps: 2)])
        let announcements = Set(WorkoutEngine.buildSteps(for: p).map(\.announcement))
        #expect(announcements.isSubset(of: known))
    }

    @Test func workStepsCarryExerciseNameAndRepDetail() {
        let p = plan(exercises: [exercise(name: "Squats", reps: 2)])
        let workSteps = WorkoutEngine.buildSteps(for: p).filter { $0.kind == .work }
        #expect(workSteps.count == 2)
        #expect(workSteps[0].title == "Squats")
        #expect(workSteps[0].detail == "Rep 1 of 2")
        #expect(workSteps[1].detail == "Rep 2 of 2")
    }

    @Test func nextNamePointsAtUpcomingExercise() {
        let p = plan(exercises: [exercise(name: "A"), exercise(name: "B")])
        let steps = WorkoutEngine.buildSteps(for: p)
        // The switch step between A and B must point at B.
        let switchStep = steps.first { $0.kind == .switching }
        #expect(switchStep?.nextName == "B")
        // The final work step has nothing after it.
        #expect(steps.last?.nextName == nil)
    }

    // MARK: - Engine lifecycle

    @Test func engineStartEntersFirstStep() {
        let engine = WorkoutEngine(plan: plan(exercises: [exercise()]), coach: SpeechCoach())
        engine.start()
        #expect(engine.currentStep?.kind == .getReady)
        #expect(engine.secondsRemaining == 5)
        #expect(!engine.isFinished)
        engine.end()
        #expect(engine.isFinished)
    }

    @Test func skipAdvancesThroughStepsToFinish() {
        let engine = WorkoutEngine(plan: plan(exercises: [exercise(reps: 1)]), coach: SpeechCoach())
        engine.start()          // getReady
        engine.skip()           // -> work
        #expect(engine.currentStep?.kind == .work)
        engine.skip()           // past the last step -> finished
        #expect(engine.isFinished)
    }

    @Test func skipWhilePausedDoesNothing() {
        let engine = WorkoutEngine(plan: plan(exercises: [exercise()]), coach: SpeechCoach())
        engine.start()
        engine.togglePause()
        engine.skip()
        #expect(engine.currentStep?.kind == .getReady)
        engine.end()
    }
}

struct ModelCodingTests {

    @Test func legacyPlanJSONWithoutReminderDecodes() throws {
        // Plans saved before the reminder feature must keep decoding.
        let legacy = """
        [{"id":"5D2C8B6A-1111-2222-3333-444455556666","name":"Legacy","repetitions":1,"switchSeconds":10,"exercises":[{"id":"5D2C8B6A-7777-8888-9999-000011112222","name":"Push-ups","repetitions":3,"workSeconds":30,"restSeconds":15}]}]
        """
        let plans = try JSONDecoder().decode([WorkoutPlan].self, from: Data(legacy.utf8))
        #expect(plans.count == 1)
        #expect(plans[0].reminder == nil)
        #expect(plans[0].exercises[0].repetitions == 3)
    }

    @Test func planRoundTripsThroughCodable() throws {
        var plan = WorkoutPlan.sample
        plan.reminder = PlanReminder(enabled: true, hour: 7, minute: 30, weekdays: [2, 4, 6], leadMinutes: 15)
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(WorkoutPlan.self, from: data)
        #expect(decoded == plan)
    }

    @Test func logEntryRoundTripsThroughCodable() throws {
        let entry = WorkoutLogEntry(
            planID: UUID(), planName: "Arms", date: Date(),
            durationSeconds: 542, completed: true, exercisesCount: 5
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(WorkoutLogEntry.self, from: data)
        #expect(decoded == entry)
    }
}
