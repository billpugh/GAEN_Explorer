//
//  ExposureAnalysis.swift
//  GAEN_Explorer
//
//  Created by Bill on 5/28/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import ExposureNotification
import Foundation

struct ExposureKey: Hashable, CustomStringConvertible {
    var description: String {
        day
    }

    let transmissionRiskLevel: ENRiskLevel

    let duration: Int
    var date: Date
    var day: String {
        dayFormatter.string(from: date)
    }

    init(info: CodableExposureInfo) {
        self.date = info.date
        self.duration = info.exposureInfoDuration
        self.transmissionRiskLevel = info.transmissionRiskLevel
    }
}

// 50    55    58    61    64    67    70    73

// 55  67    50     58    61    64    70    73

let multipassThresholds = [58, 66, 64, 68, 56, 64, 60, 68, 52, 58, 54, 62, 48, 62]
// 58 66   64 70   56 _64_   60 68  52 _58_  54 62
// 58 66   64 68   56 64   60 68  52 58  54 62 48 62

let lowerThresholdMeaningful = 58
let upperThresholdMeaningful = 64
let numberAnalysisPasses = 1 // multipassThresholds.count / 2

let phoneAttenuationHandicapValues = [
    "iPhone SE": 4,
    "iPhone 11 Pro": 0,
    "iPhone XS": 0,
    "iPhone SE (2nd generation)": 2,
]

var phoneAttenuationHandicap: Int {
    if true {
        return 0
    }
    return phoneAttenuationHandicapValues[deviceModelName(), default: 0]
}

func getAttenuationDurationThresholds(pass: Int) -> [Int] {
    [multipassThresholds[2 * (pass - 1)], multipassThresholds[2 * (pass - 1) + 1]]
}

func uniqueSortedThresholds() -> [Int] {
    Set(multipassThresholds).sorted()
}
