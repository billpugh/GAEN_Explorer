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

let multipassThresholds2 = [[58, 66],
                            [64, 68],
                            [56, 64],
                            [60, 68],
                            [52, 58],
                            [54, 62],
                            [50, 62],
                            [66, 70],
                            [68, 72]]

let multipassThresholds3 = [[10, 15, 27], [27, 33, 51], [51, 63, 72]]
// 10, 15, 27, 33, 51, 63, 73, UINT8_MAX};

let multipassThresholds = [[58, 66, 70],
                           [64, 68, 72],
                           [56, 64, 70],
                           [60, 68, 76],
                           [52, 58, 72],
                           [54, 62, 74],
                           [50, 61, 68],
                           [54, 63, 70],
                           [66, 70],
                           [68, 72]]
// 58 66   64 70   56 _64_   60 68  52 _58_  54 62
// 58 66   64 68   56 64   60 68  52 58  54 62 48 62

let lowerThresholdMeaningful = 58
let upperThresholdMeaningful = 64
let numberAnalysisPasses = multipassThresholds.count

func getAttenuationDurationThresholds(pass: Int) -> [Int] {
    multipassThresholds[pass - 1]
}

func uniqueSortedThresholds() -> [Int] {
    Set(multipassThresholds.joined()).sorted()
}
