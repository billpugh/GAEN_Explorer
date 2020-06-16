//
//  GAEN_ExplorerTests.swift
//  GAEN ExplorerTests
//
//  Created by Bill on 6/11/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import XCTest

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
        XCTAssertEqual(z.isExact, false)
        let xy = x + y
        XCTAssertEqual(xy, 15)
        XCTAssertEqual(xy.isExact, true)
        let xz = x + z
        XCTAssertEqual(xz.lb, 35)
        XCTAssertEqual(xz.isExact, false)
        let intersectionAY = intersection(a, y)
        XCTAssertEqual(intersectionAY, 10)
        let exactly30 = BoundedInt(exact: 30)
        let combination = z.intersection(exactly30)
        XCTAssertEqual(combination.lb, 30)
        XCTAssertEqual(combination.isExact, true)
    }

    func testCodableExposureInfo() throws {
        let info = CodableExposureInfo(date: daysAgo(2), transmissionRiskLevel: 5)
            .updated(thresholds: [50, 64], buckets: [5, 5, 15])
        XCTAssertEqual(info.totalDuration, 25)
        XCTAssertEqual(info.durations[50]!, 5)
        XCTAssertEqual(info.durations[64]!, 10)
        XCTAssertEqual(info.durationsExceeding[50]!, 20)
        XCTAssertEqual(info.durationsExceeding[64]!, 15)
    }

    func testCodableExposureInfo1() throws {
        print("testCodableExposureInfo1")
        let info = CodableExposureInfo(date: daysAgo(2), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 61], buckets: [5, 25, 0])
            .updated(thresholds: [50, 58], buckets: [0, 25, 5])
        XCTAssertEqual(info.totalDuration, BoundedInt(exact: 30))
        XCTAssertEqual(info.durations[50]!, 0)
        XCTAssertEqual(info.durations[55]!, 5)
        XCTAssertEqual(info.durations[58]!, 25)
        XCTAssertEqual(info.durations[61]!, BoundedInt(exact: 30))

        XCTAssertEqual(info.durationsCSV, ", 5, 25, 30, 30")
        XCTAssertEqual(info.durationsExceedingCSV, "30, 25, 5, , ")

        print(info.sortedThresholds)
        print(info.totalDuration)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)
    }

    func testCodableExposureInfo2() throws {
        var info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 67], buckets: [25, 30, 30])
        XCTAssertEqual(info.totalDuration.lb, 85)
        XCTAssertEqual(info.totalDuration.isExact, false)
        XCTAssertEqual(info.durations[55]!, 25)

        info.update(thresholds: [50, 64], buckets: [5, 30, 30])
        XCTAssertEqual(info.durations[50]!, 5)
        XCTAssertEqual(info.durations[55]!, 25)

        XCTAssertEqual(info.durationsCSV, "5, 25, 35+, 55+, 85+")
        XCTAssertEqual(info.durationsExceedingCSV, "80+, 60+, 30+, 30+, ")

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
            .updated(thresholds: [50, 58], buckets: [0, 0, 30])
            .updated(thresholds: [61, 67], buckets: [0, 0, 30])
            .updated(thresholds: [64, 70], buckets: [0, 5, 25])
        print(info.sortedThresholds)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)
        XCTAssertEqual(info.totalDuration, BoundedInt(exact: 30))

        XCTAssertEqual(info.durationsCSV, ", , , , , , 5, 30")
        XCTAssertEqual(info.durationsExceedingCSV, "30, 30, 30, 30, 30, 30, 25, ")

        XCTAssertEqual(info.totalTime(atNoMoreThan: maxAttenuation), BoundedInt(exact: 30))

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

        XCTAssertEqual(info.totalDuration, BoundedInt(exact: 45))

        XCTAssertEqual(info.durationsCSV, "5, 5, 5, 5, 15, 35, 35, 45, 45")
        XCTAssertEqual(info.durationsExceedingCSV, "40, 40, 40, 40, 30, 10, 10, , ")
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

        XCTAssertEqual(info.totalDuration, BoundedInt(exact: 40))
        XCTAssertEqual(info.durationsCSV, "5, 25, 35, 40, 40, 40, 40, 40, 40")
        XCTAssertEqual(info.durationsExceedingCSV, "35, 15, 5, , , , , , ")

        //
    }

    func testCodableExposureInfo6() throws {
        let info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 61], buckets: [25, 15, 0])
            .updated(thresholds: [52, 58], buckets: [5, 30, 10])
            .updated(thresholds: [67, 73], buckets: [30, 0, 0])
            .updated(thresholds: [64, 70], buckets: [30, 0, 0])
        print(info.sortedThresholds)
        print(info.totalDuration)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)
        XCTAssertEqual(info.totalDuration, 45)
        XCTAssertEqual(info.durationsCSV, "5, 25, 35...40, 40, 40+, 40+, 40+, 40+, 45+")
        XCTAssertEqual(info.durationsExceedingCSV, "40+, 15, 10, , , , , , ")
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

        XCTAssertEqual(info.totalDuration, 65)
        XCTAssertEqual(info.durationsCSV, ", 5, 5, 15, 20, 30...35, 35, 55+, 65+")
        XCTAssertEqual(info.durationsExceedingCSV, "65+, 60+, 60+, 50+, 40, 35, 25, 10, ")
        XCTAssertEqual(info.timeInBucket(upperBound: 64), 5)
        let thresholds = info.thresholdData
        let threshold64 = thresholds[4]
        XCTAssertEqual(threshold64.attenuation, 64)
        XCTAssertEqual(threshold64.totalTime, 20)
        XCTAssertEqual(threshold64.timeInBucket, 5)
        let threshold67 = thresholds[5]
        XCTAssertEqual(threshold67.attenuation, 67)
        XCTAssertEqual(threshold67.totalTime, BoundedInt(30, 35))
        XCTAssertEqual(threshold67.timeInBucket, BoundedInt(10, 15))
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

        XCTAssertEqual(info1.durations[60]!, BoundedInt(exact: 35))

        XCTAssertEqual(info1.durations[61]!.lb, 35)
        XCTAssertEqual(info1.durations[61]!.isExact, false)
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
        XCTAssertEqual(info.totalDuration, BoundedInt(exact: 75))
        let thresholds = info.thresholdData
        XCTAssertEqual(thresholds[1].totalTime, BoundedInt(exact: 35))
        XCTAssertEqual(thresholds[0].totalTime, BoundedInt(exact: 25))
        XCTAssertEqual(thresholds[2].totalTime, BoundedInt(exact: 50))
        XCTAssertEqual(thresholds[3].totalTime, BoundedInt(exact: 60))
    }

    func testMakeNonDecreasing() throws {
        let dict: [Int: BoundedInt] = [3: 5, 5: BoundedInt(lb: 0), 6: BoundedInt(lb: 0), 7: BoundedInt(lb: 10), 8: 10]
        let expect: [Int: BoundedInt] = [3: 5, 5: BoundedInt(5, 10), 6: BoundedInt(5, 10), 7: 10, 8: 10]

        XCTAssertEqual(nonDecreasing(dict, upperBound: 10), expect)
    }

    //    func testPerformanceExample() throws {
    //        // This is an example of a performance test case.
    //        measure {
    //            // Put the code you want to measure the time of here.
    //        }
    //    }
}
