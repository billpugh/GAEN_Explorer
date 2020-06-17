//
//  ExhaustiveTests.swift
//  GAEN ExplorerTests
//
//  Created by Bill on 6/15/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import XCTest

struct ExhaustiveCase {
    static func grabBits(_ bits: UInt32) -> Int {
        var remainingBits = bits
        var result = 0
        var value = 1
        while remainingBits != 0 {
            if remainingBits & 0x01 != 0 {
                result += value
            }
            value *= 2
            remainingBits >>= ExhaustiveCase.keys.count
        }
        return result
    }

    static let keys: [Int] = (multipassThresholds + [maxAttenuation]).sorted()
    let seed: UInt32
    let truth: [Int: Int]
    init(seed: UInt32) {
        self.seed = seed
        var v = seed
        var durations: [Int: Int] = [:]
        for dB in ExhaustiveCase.keys {
            durations[dB] = ExhaustiveCase.grabBits(v) * 5
            v >>= 1
            if v == 0 {
                break
            }
        }
        truth = durations
    }

    func durations(dB: Int) -> Int {
        truth.filter {
            $0.key <= dB
        }.values.reduce(0,+)
    }

    func durations(exceeding: Int) -> Int {
        truth.filter {
            exceeding < $0.key
        }.values.reduce(0,+)
    }

    func getBuckets(thresholds: [Int]) -> [Int] {
        assert(thresholds.count == 2)
        return [min(30, durations(dB: thresholds[0])),
                min(30, truth.filter {
                    thresholds[0] < $0.key && $0.key <= thresholds[1]
                }.values.reduce(0,+)),
                min(30, durations(exceeding: thresholds[1]))]
    }

    func check(listBad: Bool = false) -> Bool {
        var info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
        var anyExactBuckets: Bool = false
        for pass in 1 ... numberAnalysisPasses {
            let thresholds = getAttenuationDurationThresholds(pass: pass)
            let buckets = getBuckets(thresholds: thresholds)
            if buckets.filter({ $0 >= 30 }).isEmpty {
                anyExactBuckets = true
            }
            info.update(thresholds: thresholds, buckets: buckets)
            verify(info)
        }
        let good = isExact(info) || !anyExactBuckets
        if !good, listBad {
            print("bad ExhaustiveCheck \(seed) \(truth) ")
            if !info.durations.values.filter({ !$0.isNearlyExact }).isEmpty {
                print(" inexact durations: \(info.durationsCSV)")
            }
            if !info.durationsExceeding.values.filter({ !$0.isNearlyExact }).isEmpty {
                print(" inexact durationsExceeding: \(info.durationsExceedingCSV)")
            }
            if !info.durations.keys.map({ info.timeInBucket(upperBound: $0) }).filter({ !$0.isNearlyExact }).isEmpty {
                print(" inexact timeInBuckets: \(info.timeInBucketCSV)")
            }
            for ra in info.rawAnalysis {
                print("  .updated(thresholds: \(ra.thresholds), buckets: \(ra.bucket))")
            }
        }
        return good
    }

    func isExact(_ info: CodableExposureInfo) -> Bool {
        if !info.durations.values.filter({ !$0.isNearlyExact }).isEmpty {
            return false
        }
        if !info.durationsExceeding.values.filter({ !$0.isNearlyExact }).isEmpty {
            return false
        }
        if !info.durations.keys.map({ info.timeInBucket(upperBound: $0) }).filter({ !$0.isNearlyExact }).isEmpty {
            return false
        }
        return true
    }

    func verify(_ info: CodableExposureInfo) {
        info.durations.forEach { dB, value in
            XCTAssert(value.matches(durations(dB: dB)))
        }
        info.durationsExceeding.forEach { dB, value in
            XCTAssert(value.matches(durations(exceeding: dB)))
        }
    }
}

class ExhaustiveTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        var countNotGood = 0
        for i in 0 ... 10000 {
            if ExhaustiveCase(seed: UInt32(i)).check(listBad: true) {
                countNotGood += 1
            }
        }
        print(countNotGood)
        XCTAssertGreaterThanOrEqual(countNotGood, 9998)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            for i in 0 ... 1000 {
                _ = ExhaustiveCase(seed: UInt32(i)).check()
            }
        }
    }
}
