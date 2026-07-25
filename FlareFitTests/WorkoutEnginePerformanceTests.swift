//
//  WorkoutEnginePerformanceTests.swift
//  FlareFitTests
//
//  Performance guardrail for the pure step-building path (the hottest pure
//  function — a plan is flattened into steps up front). Uses XCTest's measure
//  (Swift Testing has no perf-measure equivalent yet).
//

import XCTest
@testable import FlareFit

final class WorkoutEnginePerformanceTests: XCTestCase {

    @MainActor
    func testBuildStepsPerformanceLargePlan() {
        // A deliberately heavy plan: 20 exercises × 5 reps × 10 rounds
        // (~2,000+ steps) — far larger than any realistic user plan.
        let exercises = (1...20).map {
            Exercise(name: "Exercise \($0)", repetitions: 5, workSeconds: 30, restSeconds: 15)
        }
        let plan = WorkoutPlan(name: "Stress", repetitions: 10, switchSeconds: 10, exercises: exercises)

        measure {
            _ = WorkoutEngine.buildSteps(for: plan)
        }
    }
}
