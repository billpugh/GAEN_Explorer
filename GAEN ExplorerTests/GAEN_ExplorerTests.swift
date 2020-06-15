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
        let x: IntLB = 5
        let y: IntLB = 10
        let z: IntLB = 30
        let a: IntLB = IntLB(7, false)
        XCTAssertEqual(z.isExact, false)
        let xy = x + y
        XCTAssertEqual(xy.value, 15)
        XCTAssertEqual(xy.isExact, true)
        let xz = x + z
        XCTAssertEqual(xz.value, 35)
        XCTAssertEqual(xz.isExact, false)
        let intersectionAY = intersection(a, y)
        XCTAssertEqual(intersectionAY.value, 10)
        XCTAssertEqual(intersectionAY.isExact, true)
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
        XCTAssertEqual(info.totalDuration, IntLB(exact: 30))
        XCTAssertEqual(info.durations[50]!, 0)
        XCTAssertEqual(info.durations[55]!, 5)
        XCTAssertEqual(info.durations[58]!, 25)
        XCTAssertEqual(info.durations[61]!, IntLB(exact: 30))
    }

    func testCodableExposureInfo2() throws {
        var info = CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 67], buckets: [25, 30, 30])
        XCTAssertEqual(info.totalDuration.value, 85)
        XCTAssertEqual(info.totalDuration.isExact, false)
        XCTAssertEqual(info.durations[55]!, 25)

        info.update(thresholds: [50, 64], buckets: [5, 30, 30])
        XCTAssertEqual(info.durations[50]!, 5)
        XCTAssertEqual(info.durations[55]!, 25)

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
        XCTAssertEqual(info.totalDuration.value, 30)
        XCTAssertEqual(info.totalDuration.isExact, true)
        XCTAssertEqual(info.totalTime(atNoMoreThan: maxAttenuation).value, 30)
        XCTAssertEqual(info.totalTime(atNoMoreThan: maxAttenuation).isExact, true)

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
        print(info.sortedThresholds)
        print(info.totalDuration)
        print(info.durationsCSV)
        print(info.durationsExceedingCSV)

        //
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
        XCTAssertEqual(threshold50.cumulativeDuration, 5)

        let threshold55 = thresholds[1]
        XCTAssertEqual(threshold55.attenuation, 55)

        let threshold73 = thresholds[7]
        XCTAssertEqual(threshold73.attenuation, 73)
        XCTAssertEqual(threshold73.exceedingDuration.value, 30)
        XCTAssertEqual(threshold73.exceedingDuration.isExact, false)
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

        XCTAssertEqual(info1.durations[60]!.value, 35)
        XCTAssertEqual(info1.durations[60]!.isExact, true)
        XCTAssertEqual(info1.durations[61]!.value, 35)
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
        XCTAssertEqual(info.totalDuration, IntLB(exact: 75))
        let thresholds = info.thresholdData
        XCTAssertEqual(thresholds[1].cumulativeDuration, IntLB(exact: 35))
        XCTAssertEqual(thresholds[0].cumulativeDuration, IntLB(exact: 25))
        XCTAssertEqual(thresholds[2].cumulativeDuration, IntLB(exact: 50))
        XCTAssertEqual(thresholds[3].cumulativeDuration, IntLB(exact: 60))
    }

    func testMakeNonDecreasing() throws {
        let dict: [Int: IntLB] = [3: 5, 5: IntLB(0, false), 6: IntLB(0, false), 7: IntLB(10, false), 8: 10]
        let expect: [Int: IntLB] = [3: 5, 5: IntLB(5, false), 6: IntLB(5, false), 7: 10, 8: 10]

        XCTAssertEqual(nonDecreasing(dict, upperBound: 10), expect)
    }

//    func testPerformanceExample() throws {
//        // This is an example of a performance test case.
//        measure {
//            // Put the code you want to measure the time of here.
//        }
//    }
}
