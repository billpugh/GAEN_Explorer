//
//  GAEN_ExplorerTests.swift
//  GAEN ExplorerTests
//
//  Created by Bill on 6/11/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import XCTest

func XCTAssertMatches(_ boundedInt: BoundedInt?, _ int: Int, _ msg: String = "") {
    guard let bi = boundedInt else {
        XCTAssertNotNil(boundedInt)
        return
    }
    XCTAssert(bi.matches(int), "XCTAssertMatch failed: \(bi) doesn't match \(int) \(msg)")
}

func XCTAssertMatches(_ boundedInt: BoundedInt?, _ expected: BoundedInt, _ msg: String = "") {
    guard let bi = boundedInt else {
        XCTAssertNotNil(boundedInt)
        return
    }
    XCTAssert(expected.matches(bi), "XCTAssertMatch failed: \(bi) doesn't match \(expected) \(msg)")
}

class ConfigurationTests: XCTestCase {
    func testConfig() throws {
        let configString = CodableExposureConfiguration.getExposureConfigurationString()
        let config = CodableExposureConfiguration.getCodableExposureConfiguration()
        let enConfig = config.asExposureConfiguration()
        print("configString: \(configString)\n")
        print("config: \(config)\n")
        print("enConfig: \(enConfig)\n")
        print("enConfig.attenuationDurationThresholds \(enConfig.value(forKey: "attenuationDurationThresholds")!)\n")
        print("enConfig.metadata[\"attenuationDurationThresholds\"]:  \(enConfig.metadata!["attenuationDurationThresholds"]!)\n")
    }
}

class GAEN_ExplorerTests: XCTestCase {
    override func setUpWithError() throws {
        CodableExposureInfo.cvsTestingMode = true
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testIntegerLowerBound() throws {
        let x: BoundedInt = 5
        let y: BoundedInt = 10
        let z: BoundedInt = 30
        let a = BoundedInt(7, 20)
        XCTAssertEqual(z.isNearlyExact, false)
        let xy = x + y
        XCTAssertMatches(xy, 15)
        let xz = x + z
        XCTAssertEqual(xz.lb, 35)
        XCTAssertEqual(xz.isNearlyExact, false)
        let intersectionAY = intersection(a, y)
        XCTAssertMatches(intersectionAY, 10)
        let exactly30 = BoundedInt(uncapped: 30)
        let combination = z.intersection(exactly30)
        XCTAssertEqual(combination.lb, 30)
        XCTAssertEqual(combination.ub, 30)

        let w = BoundedInt(0, 4)
        print(w)
    }

    func testCodableExposureInfo1() throws {
        var info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)

        info.updateAndDump(duration: BoundedInt(precise: 31), thresholds: [58, 66, 70], buckets: [0, 29, 3, 0])
        info.update(thresholds: [64, 68, 72], buckets: [30, 3, 0, 0])
        info.update(thresholds: [56, 64, 70], buckets: [3, 30, 3, 0])
        info.update(thresholds: [60, 68, 76], buckets: [3, 30, 0, 0])
        info.update(thresholds: [52, 58, 72], buckets: [3, 0, 30, 0])
        info.update(thresholds: [54, 62, 74], buckets: [3, 8, 26, 0])
        info.update(thresholds: [50, 62], buckets: [3, 8, 26, 0])
        info.update(thresholds: [66, 70], buckets: [30, 3, 0, 0])
        info.update(thresholds: [68, 72], buckets: [30, 0, 0, 0])

        print(info.sortedThresholds)
        print(info.totalDuration)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)
        print(info.timeInBucketCSV)
    }

    func testCodableExposureInfo2() throws {
        var info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)

        info.updateAndDump(thresholds: [10, 15, 27], buckets: [0, 0, 0, 30])
        info.updateAndDump(thresholds: [27, 33, 51], buckets: [0, 18, 30, 0])
        info.updateAndDump(thresholds: [51, 63, 72], buckets: [30, 0, 0, 0])

        print(info.sortedThresholds)
        print(info.totalDuration)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)
        print(info.timeInBucketCSV)
        print()
        let thresholds = info.thresholdData
        for t in thresholds {
            print(t)
        }
        print("done")
    }

    func testCodableExposureInfo17() throws {
        var info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)

        info.updateAndDump(duration: BoundedInt(precise: 29), thresholds: [58, 66, 70], buckets: [30, 0, 0, 0])
        info.update(thresholds: [64, 68, 72], buckets: [30, 0, 0, 0])

        print(info.sortedThresholds)
        print(info.totalDuration)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)
        print(info.timeInBucketCSV)
    }

    func testThresholds() throws {
        let info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 67], buckets: [25, 30, 30])
            .updated(thresholds: [50, 64], buckets: [5, 30, 30])
            .updated(thresholds: [61, 73], buckets: [30, 30, 30])
            .updated(thresholds: [58, 70], buckets: [30, 30, 30])

        let thresholds = info.thresholdData
        let threshold50 = thresholds[0]
        XCTAssertEqual(threshold50.attenuation, 50)
        XCTAssertEqual(threshold50.totalTime, 5)

        let threshold55 = thresholds[1]
        XCTAssertEqual(threshold55.attenuation, 55)

        let threshold73 = thresholds[7]
        XCTAssertEqual(threshold73.attenuation, 73)
    }

    func testThresholds0() throws {
        let info0 = CodableExposureInfo.testData[0]
        _ = info0.meaningfulDuration
        _ = info0.thresholdData
    }

    func testThresholds1() throws {
        let info1 = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 67], buckets: [20, 30, 30])
            .updated(thresholds: [50, 64], buckets: [5, 30, 30])
            .updated(thresholds: [61, 73], buckets: [30, 30, 30])
            .updated(thresholds: [58, 70], buckets: [25, 30, 30])
            .updated(thresholds: [52, 60], buckets: [10, 25, 30])

        print(info1.sortedThresholds)
        print(info1.totalDuration)
        print(info1.durationsCSV)
        print(info1.durationsExceedingCSV)

        XCTAssertMatches(info1.durations[60], 35)

        XCTAssertMatches(info1.durations[61], 35)
        _ = info1.meaningfulDuration
        _ = info1.thresholdData
    }

    func testThresholds2() throws {
        let info2 = CodableExposureInfo.testData[2]
        _ = info2.meaningfulDuration
        _ = info2.thresholdData
    }

    func testThresholds3() {
        let info = CodableExposureInfo(date: daysAgo(2), transmissionRiskLevel: 5)
            .updated(thresholds: [50, 64], buckets: [25, 25, 25])
            .updated(thresholds: [58, 70], buckets: [30, 25, 15])
        XCTAssertMatches(info.totalDuration, 75)
        let thresholds = info.thresholdData

        XCTAssertMatches(thresholds[0].totalTime, 25)
        XCTAssertMatches(thresholds[1].totalTime, 35)
        XCTAssertMatches(thresholds[2].totalTime, 50)
        XCTAssertMatches(thresholds[3].totalTime, 60)
    }

    func testMakeNonDecreasing() throws {
        let dict: [Int: BoundedInt] = [3: 5, 5: BoundedInt(lb: 0), 6: BoundedInt(lb: 0), 7: BoundedInt(lb: 8), 8: 10]
        let expect: [Int: BoundedInt] = [3: 5, 5: BoundedInt(5, 10), 6: BoundedInt(5, 10), 7: BoundedInt(8, 10), 8: 10]
        let updatedDict = nonDecreasing(dict, upperBound: 10)
        for (k, v) in updatedDict {
            XCTAssertMatches(v, expect[k]!, "\(k): \(v.preciseLB)...\(v.ub) != \(expect[k]!.preciseLB)...\(expect[k]!.ub)")
        }
    }

    func testMakeNonDecreasing2() throws {
        let dict: [Int: BoundedInt] = [3: 5, 5: 10, 6: 15, 7: BoundedInt(10, 15), 8: 10, 9: 20, 10: 20, 11: BoundedInt(uncapped: 40)]
        let expect: [Int: BoundedInt] = [3: 5, 5: 10, 6: 15, 7: 15, 8: 15, 9: 20, 10: 20, 11: BoundedInt(uncapped: 40)]
        let updatedDict = nonDecreasing(dict, upperBound: 40)
        print(updatedDict.keys.sorted().map { "\(updatedDict[$0]!)" }.joined(separator: ", "))
        print(updatedDict.keys.sorted().map { "\(expect[$0]!)" }.joined(separator: ", "))
        for (k, v) in updatedDict {
            XCTAssertMatches(v, expect[k]!, "\(k): \(v.preciseLB)...\(v.ub) != \(expect[k]!.preciseLB)...\(expect[k]!.ub)")
        }
    }

    //    func testPerformanceExample() throws {
    //        // This is an example of a performance test case.
    //        measure {
    //            // Put the code you want to measure the time of here.
    //        }
    //    }
}
