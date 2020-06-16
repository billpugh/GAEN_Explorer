//
//  GroundTruthTests.swift
//  GAEN ExplorerTests
//
//  Created by Bill on 6/14/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import XCTest

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    init(seed: Int) {
        srand48(seed * 15732 + 2349)
    }

    func next() -> UInt64 {
        return UInt64(drand48() * Double(UInt64.max))
    }
}

struct GroundTruth {
    var random: SeededRandomNumberGenerator
    init(seed: Int) {
        random = SeededRandomNumberGenerator(seed: seed)
    }

    var truth = [Int](repeating: 0, count: maxAttenuation)
    mutating func addUniform(_ count: Int, block: Int, min: Int, max: Int) {
        for _ in 0 ..< count {
            truth[Int.random(in: min ... max, using: &random)] += block
        }
    }

    func durations(dB: Int) -> Int {
        truth[0 ... dB].reduce(0, +)
    }

    func durations(exceeding: Int) -> Int {
        if exceeding + 1 >= truth.count {
            return 0
        }
        return truth[exceeding + 1 ..< truth.count].reduce(0, +)
    }

    func getBuckets(thresholds: [Int]) -> [BoundedInt] {
        var result = [Int](repeating: 0, count: thresholds.count + 1)
        var index = 0
        for dB in 0 ..< truth.count {
            result[index] += truth[dB]
            if index < thresholds.count, dB == thresholds[index] {
                index += 1
            }
        }
        return result.map { BoundedInt($0) }
    }

    func verify(info: CodableExposureInfo) {
        info.durations.forEach { dB, value in
            XCTAssert(value.matches(durations(dB: dB)))
        }
        info.durationsExceeding.forEach { dB, value in
            XCTAssert(value.matches(durations(exceeding: dB)))
        }
    }
}

class GroundTruthTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testRandomExamples() throws {
        for seed in 0 ..< 1000 {
            var gt = GroundTruth(seed: seed)
            gt.addUniform(Int.random(in: 6 ... 20, using: &gt.random), block: 5, min: 45, max: 70)
            var info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            for pass in 1 ... numberAnalysisPasses {
                let thresholds = getAttenuationDurationThresholds(pass: pass)
                info.update(thresholds: thresholds, buckets: gt.getBuckets(thresholds: thresholds))
            }
            gt.verify(info: info)
        }
    }
}
