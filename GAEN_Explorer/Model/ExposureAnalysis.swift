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

    var date: Date
    var day: String {
        LocalStore.shared.dayFormatter.string(from: date)
    }

    init(info: CodableExposureInfo) {
        self.date = info.date
        self.transmissionRiskLevel = info.transmissionRiskLevel
    }
}

// 50    55    58    61    64    67    70    73
let multipassThresholds = [50, 55, 61, 70, 58, 67, 64, 73]

let numberAnalysisPasses = multipassThresholds.count / 2

func getAttenuationDurationThresholds(pass: Int) -> [Int] {
    [multipassThresholds[2 * (pass - 1)], multipassThresholds[2 * (pass - 1) + 1]]
}
