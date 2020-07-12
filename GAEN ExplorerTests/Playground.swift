//
//  Playground.swift
//  GAEN ExplorerTests
//
//  Created by Bill on 6/30/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import XCTest

class Playground: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        let dict = [50: 0, 52: 0, 54: 0, 56: 0, 58: 0, 60: 6, 62: 20, 64: 3, 66: 3, 68: 1, 70: 0, 72: 0, 74: 0]
        let r = CodableExposureInfo.quantizeScans(dict.sorted { $0.key < $1.key })
        print(r)
    }
}
