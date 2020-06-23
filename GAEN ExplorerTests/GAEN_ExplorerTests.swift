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

class GAEN_ExplorerTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testIntegerLowerBound() throws {
        let x: BoundedInt = 5
        let y: BoundedInt = 10
        let z: BoundedInt = 30
        let a: BoundedInt = BoundedInt(7, 20)
        XCTAssertEqual(z.isNearlyExact, false)
        let xy = x + y
        XCTAssertMatches(xy, 15)
        let xz = x + z
        XCTAssertEqual(xz.lb, 30)
        XCTAssertEqual(xz.isNearlyExact, false)
        let intersectionAY = intersection(a, y)
        XCTAssertMatches(intersectionAY, 10)
        let exactly30 = BoundedInt(uncapped: 30)
        let combination = z.intersection(exactly30)
        XCTAssertEqual(combination.lb, 30)
        XCTAssertEqual(combination.ub, 30)
    }

    func testCodableExposureInfo() throws {
        let info = CodableExposureInfo(date: daysAgo(2), transmissionRiskLevel: 5)
            .updated(thresholds: [50, 64], buckets: [5, 5, 15])
        XCTAssertMatches(info.totalDuration, 25)
        XCTAssertMatches(info.durations[50], 5)
        XCTAssertMatches(info.durations[64], 10)
        XCTAssertMatches(info.durationsExceeding[50], 20)
        XCTAssertMatches(info.durationsExceeding[64], 15)
    }

    func testCodableExposureInfoTestData0() throws {
        let info = CodableExposureInfo.testData[0]
        print(info.thresholdsCSV)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)
        print(info.timeInBucketCSV)

        XCTAssertEqual(info.durationsCSV, "25, 26...43, 42...50, 48...64, 63...75")
        XCTAssertEqual(info.durationsExceedingCSV, "42...50, 32...40, 25, 15, ")
        XCTAssertEqual(info.timeInBucketCSV, "25, 2...18, 7...19, 6...14, 15")
    }

    func testCodableExposureInfoTestData1() throws {
        let info = CodableExposureInfo.testData[1]
        print(info.thresholdsCSV)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)
        print(info.timeInBucketCSV)

        XCTAssertEqual(info.durationsCSV, ", 5, 5, 7...15, 20, 26...33, 27...35, 47...54, 53...60")
        XCTAssertEqual(info.durationsExceedingCSV, "36...60, 35...59, 35...59, 33...53, 32...40, 27...34, 25, 10, ")
        XCTAssertEqual(info.timeInBucketCSV, ", 5, 0...4, 2...14, 1...13, 6...13, 2...9, 12...19, 10")
    }

    func testCodableExposureInfo1() throws {
        let info = CodableExposureInfo(date: daysAgo(2), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 61], buckets: [5, 25, 0])
            .updated(thresholds: [50, 58], buckets: [0, 25, 5])
        XCTAssertMatches(info.totalDuration, 30)
        XCTAssertMatches(info.durations[50], 0)
        XCTAssertMatches(info.durations[55], 5)
        XCTAssertMatches(info.durations[58], 25)
        XCTAssertMatches(info.durations[61], 30)

        XCTAssertEqual(info.durationsCSV, ", 5, 25, 22...30, 22...30")
        XCTAssertEqual(info.durationsExceedingCSV, "22...30, 25, 5, , ")

        print(info.sortedThresholds)
        print(info.totalDuration)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)
    }

    func testCodableExposureInfo2() throws {
        var info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 67], buckets: [25, 30, 30])
        XCTAssertMatches(info.totalDuration, 85)
        XCTAssert(info.totalDuration.isLowerBound)
        XCTAssertMatches(info.durations[55], 25)

        info.update(thresholds: [50, 64], buckets: [5, 30, 30])
        XCTAssertMatches(info.durations[50], 5)
        XCTAssertMatches(info.durations[55], 25)

        XCTAssertEqual(info.durationsCSV, "5, 25, 27+, 47+, 73+")
        XCTAssertEqual(info.durationsExceedingCSV, "68+, 52+, 26+, 26+, ")

        print(info.sortedThresholds)
        print(info.totalDuration)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)

        //
        //          .update(thresholds: [61, 73], buckets: [30, 30, 30])
        //                .update(thresholds: [58, 70], buckets: [30, 30, 30])
        //
    }

    func testCodableExposureInfo3() throws {
        var info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 61], buckets: [0, 0, 30])
        print("\(info.totalDuration)")
        info.update(thresholds: [50, 58], buckets: [0, 0, 30])
        print("\(info.totalDuration)")
        info.update(thresholds: [61, 67], buckets: [0, 0, 30])
        print("\(info.totalDuration)")
        info.update(thresholds: [64, 70], buckets: [0, 5, 25])
        print("\(info.totalDuration)")
        print(info.sortedThresholds)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)
        XCTAssertMatches(info.totalDuration, 30)

        XCTAssertEqual(info.durationsCSV, ", , , , , , 5, 30")
        XCTAssertEqual(info.durationsExceedingCSV, "30, 30, 30, 30, 30, 30, 25, ")

        XCTAssertMatches(info.totalTime(atNoMoreThan: maxAttenuation), 30)

        //
        //          .update(thresholds: [61, 73], buckets: [30, 30, 30])
        //                .update(thresholds: [58, 70], buckets: [30, 30, 30])
        //
    }

    func testCodableExposureInfo4() throws {
        let info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 61], buckets: [5, 0, 30])
            .updated(thresholds: [52, 58], buckets: [5, 0, 30])
            .updated(thresholds: [67, 73], buckets: [30, 10, 0])
            .updated(thresholds: [64, 70], buckets: [15, 20, 10])

        XCTAssertMatches(info.totalDuration, 45)

        XCTAssertEqual(info.durationsCSV, "5, 5, 5, 5, 15, 26...35, 27...35, 32...45, 33...45")
        XCTAssertEqual(info.durationsExceedingCSV, "28...44, 28...44, 28...44, 28...44, 22...30, 10, 10, , ")
        print(info.sortedThresholds)
        print(info.totalDuration)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)
        //
    }

    func testCodableExposureInfo5() throws {
        let info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 61], buckets: [25, 15, 0])
            .updated(thresholds: [52, 58], buckets: [5, 30, 5])
            .updated(thresholds: [67, 73], buckets: [30, 0, 0])
            .updated(thresholds: [64, 70], buckets: [30, 0, 0])
        print(info.sortedThresholds)

        XCTAssertMatches(info.totalDuration, 40)
        XCTAssertEqual(info.durationsCSV, "5, 25, 27...39, 32...40, 32...40, 32...40, 32...40, 32...40, 32...40")
        XCTAssertEqual(info.durationsExceedingCSV, "27...39, 15, 5, , , , , , ")

        //
    }

    func testCodableExposureInfo6() throws {
        var info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 61], buckets: [25, 15, 0])
        print("duration: \(info.duration), \(info.totalDuration)")
        info.update(thresholds: [52, 58], buckets: [5, 30, 10])
        print("duration: \(info.duration), \(info.totalDuration)")
        info.update(thresholds: [67, 73], buckets: [30, 0, 0])
        print("duration: \(info.duration), \(info.totalDuration)")
        info.update(thresholds: [64, 70], buckets: [30, 0, 0])
        print("duration: \(info.duration), \(info.totalDuration)")
        print(info.sortedThresholds)
        print(info.totalDuration)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)
        XCTAssertEqual(info.totalDuration, BoundedInt(35, 40))
        XCTAssertEqual(info.durationsCSV, "5, 25, 27...34, 32...40, 33...40, 33...40, 33...40, 33...40, 33...40")
        XCTAssertEqual(info.durationsExceedingCSV, "32...39, 15, 10, , , , , , ")
    }

    func testCodableExposureInfo7() throws {
        let info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 61], buckets: [5, 10, 30])
            .updated(thresholds: [52, 58], buckets: [0, 5, 30])
            .updated(thresholds: [67, 73], buckets: [30, 25, 10])
            .updated(thresholds: [64, 70], buckets: [20, 15, 25])
        print(info.sortedThresholds)
        print(info.totalDuration)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)

        XCTAssertEqual(info.totalDuration, BoundedInt(55, 60))
        XCTAssertEqual(info.durationsCSV, ", 5, 5, 7...15, 20, 26...33, 27...35, 47...54, 53...60")
        XCTAssertEqual(info.durationsExceedingCSV, "36...60, 35...59, 35...59, 33...53, 32...40, 27...34, 25, 10, ")
        XCTAssertMatches(info.timeInBucket(upperBound: 64), 5)
        let thresholds = info.thresholdData
        let threshold64 = thresholds[4]
        XCTAssertEqual(threshold64.attenuation, 64)
        XCTAssertMatches(threshold64.totalTime, 20)
        XCTAssertMatches(threshold64.timeInBucket, 5)
        let threshold67 = thresholds[5]
        XCTAssertEqual(threshold67.attenuation, 67)
        XCTAssertMatches(threshold67.totalTime, 30)
        XCTAssertMatches(threshold67.timeInBucket, 10)
    }

    func testCodableExposureInfo8() throws {
        let info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 61], buckets: [15, 5, 5])
            .updated(thresholds: [52, 58], buckets: [10, 10, 10])
            .updated(thresholds: [67, 73], buckets: [20, 0, 0])
            .updated(thresholds: [64, 70], buckets: [20, 5, 0])

        print(info.sortedThresholds)
        print(info.totalDuration)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)
        print(info.timeInBucketCSV)
        print(info.timeInBucket(upperBound: 55))

        XCTAssertEqual(info.totalDuration, BoundedInt(18, 20))
        XCTAssertEqual(info.durationsCSV, "8, 14, 14, 12...19, 19, 20, 20, 20, 20")
        XCTAssertEqual(info.durationsExceedingCSV, "14, 9, 8, 5, 4, , , , ")
        XCTAssertEqual(info.timeInBucketCSV, "8, 3...8, 0...3, 1...7, 0...4, 4, , , ")
    }

    func testCodableExposureInfo9() throws {
        let info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 61], buckets: [0, 5, 30])
            .updated(thresholds: [52, 58], buckets: [0, 0, 30])
            .updated(thresholds: [67, 73], buckets: [30, 5, 0])
            .updated(thresholds: [64, 70], buckets: [15, 15, 5])

        print(info.sortedThresholds)
        print(info.totalDuration)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)
        XCTAssertMatches(info.totalTime(atNoMoreThan: 67), 30)
        XCTAssert(info.totalTime(atNoMoreThan: 67).isNearlyExact)
    }

    func testCodableExposureInfo10() throws {
        let info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 61], buckets: [0, 10, 15])
            .updated(thresholds: [52, 58], buckets: [0, 0, 20])
            .updated(thresholds: [67, 73], buckets: [15, 5, 0])
            .updated(thresholds: [64, 70], buckets: [10, 15, 0])

        XCTAssertEqual(info.totalDuration, BoundedInt(20))
        XCTAssertEqual(info.durationsCSV, ", , , 9, 9, 15, 20, 20, 20")
        XCTAssertEqual(info.durationsExceedingCSV, "20, 20, 20, 14, 14, 5, , , ")
        XCTAssertEqual(info.timeInBucketCSV, ", , , 9, 0...3, 9, 5, , ")
    }

    func testCodableExposureInfo11() throws {
        let info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 61], buckets: [0, 0, 30])
            .updated(thresholds: [52, 58], buckets: [0, 0, 30])
            .updated(thresholds: [67, 73], buckets: [15, 15, 10])
            .updated(thresholds: [64, 70], buckets: [5, 15, 20])

        XCTAssertEqual(info.totalDuration, BoundedInt(30, 40))
        XCTAssertEqual(info.durationsCSV, ", , , , 5, 15, 12...20, 22...30, 28...40")
        XCTAssertEqual(info.durationsExceedingCSV, "26...40, 28...40, 28...40, 28...40, 27...35, 17...25, 20, 10, ")
        XCTAssertEqual(info.timeInBucketCSV, ", , , , 5, 6...14, 0...9, 6...14, 10")
        print(info.sortedThresholds)
        print(info.totalDuration)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)
        print(info.timeInBucketCSV)
    }

    func testCodableExposureInfo12() throws {
        let info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 61], buckets: [5, 10, 25])
            .updated(thresholds: [52, 58], buckets: [5, 5, 25])
            .updated(thresholds: [67, 73], buckets: [10, 10, 20])
            .updated(thresholds: [64, 70], buckets: [10, 10, 20])

        print(info.sortedThresholds)
        print(info.totalDuration)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)
        print(info.timeInBucketCSV)

        XCTAssertEqual(info.totalDuration, BoundedInt(30, 35))
        XCTAssertEqual(info.durationsCSV, "5, 5, 2...10, 10, 10, 10, 12...19, 12...19, 28...35")
        XCTAssertEqual(info.durationsExceedingCSV, "30, 30, 25, 25, 25, 25, 20, 20, ")
        XCTAssertEqual(info.timeInBucketCSV, "5, 0...3, 2...9, 0...4, 0...3, 0...3, 2...9, 0...4, 20")
    }

    func testCodableExposureInfo13() throws {
        let info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            .updated(thresholds: [58, 66], buckets: [10, 30, 0])
            .updated(thresholds: [64, 70], buckets: [30, 0, 0])
            .updated(thresholds: [56, 64], buckets: [5, 30, 0])
            .updated(thresholds: [60, 68], buckets: [30, 20, 0])
            .updated(thresholds: [52, 58], buckets: [0, 10, 30])
            .updated(thresholds: [54, 62], buckets: [0, 30, 10])

        print(info.sortedThresholds)
        print(info.totalDuration)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)
        print(info.timeInBucketCSV)

        XCTAssertEqual(info.totalDuration, BoundedInt(lb: 45))
        XCTAssertEqual(info.durationsCSV, ", , 5, 10, 26+, 32+, 38+, 38+, 42+, 42+, 42+")
        XCTAssertEqual(info.durationsExceedingCSV, "38+, 38+, 32+, 32+, 20, 10, , , , , ")
        XCTAssertEqual(info.timeInBucketCSV, ", , 5, 1...9, 16+, 6...14, 10, , , , ")
    }

    func testCodableExposureInfo14() throws {
        var info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)

        info.updateAndDump(duration: BoundedInt(precise: 43), thresholds: [58, 66], buckets: [10, 30, 0])
        info.update(thresholds: [64, 70], buckets: [30, 0, 0])
        info.update(thresholds: [56, 64], buckets: [5, 30, 0])
        info.update(thresholds: [60, 68], buckets: [30, 20, 0])
        info.update(thresholds: [52, 58], buckets: [0, 10, 30])
        info.updateAndDump(thresholds: [54, 62], buckets: [0, 30, 10])

        XCTAssertEqual(info.totalDuration, BoundedInt(precise: 43))
        XCTAssertEqual(info.durationsCSV, ", , 5, 10, 27, 33...37, 43, 43, 43, 43, 43")
        XCTAssertEqual(info.durationsExceedingCSV, "39...43, 39...43, 38...42, 33...37, 17, 10, , , , , ")
        XCTAssertEqual(info.timeInBucketCSV, ", , 5, 1...9, 16...21, 6...11, 10, , , , ")
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
