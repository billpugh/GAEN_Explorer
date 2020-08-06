//
//  TestOrientationTests.swift
//  TestOrientationTests
//
//  Created by Bill on 7/20/20.
//  Copyright © 2020 NinjaMonkeyCoders. All rights reserved.
//

@testable import MeasureBluetooth
import XCTest

class TestOrientationTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        var a = AccumulatingAngle()
        a = a.add(0)
        XCTAssertEqual(0, a.degrees)
        print(a.confidence)
    }

    func test2() throws {
        var a = AccumulatingAngle()
        a = a.add(degrees: 10)
        a = a.add(degrees: 350)
        XCTAssertEqual(0, a.degrees)
        print(a.confidence)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }
}
