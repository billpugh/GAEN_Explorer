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

    let attenuationValue: Int8
    let duration: Int8 // minutes
    let transmissionRiskLevel: ENRiskLevel

    var date: Date
    var day: String {
        ExposureFramework.shared.dayFormatter.string(from: date)
    }

    init(info: CodableExposureInfo) {
        self.attenuationValue = info.attenuationValue
        self.date = info.date
        self.duration = info.duration
        self.transmissionRiskLevel = info.transmissionRiskLevel
    }
}

let multipassThresholds = [50, 56, 47, 53, 44, 62]
let numberAnalysisPasses = multipassThresholds.count / 2

func getAttenuationDurationThresholds(pass: Int) -> [Int] {
    [multipassThresholds[2 * (pass - 1)], multipassThresholds[2 * (pass - 1) + 1]]
}

class ExposureAnalysis {
    let name: String
    var exposureDurations: [ExposureKey: [Int: Int]] = [:]

    func asString(_ durations: [Int: Int]) -> String {
        durations.sorted(by: { $0.0 < $1.0 }).map { "\($0): \($1)" }.joined(separator: ", ")
    }

    var allExposures: [[CodableExposureInfo]] = []
    init(name: String) {
        self.name = name
    }

    func printMe() {
        print("Encounter analysis for user \(name)")

        for (key, durations) in exposureDurations {
            print(" \(key) \(asString(durations))")
        }
    }

    func analyze(pass: Int, exposures: [CodableExposureInfo]) {
        print("analysis pass \(pass),  have \(exposures.count) exposures")

        allExposures.append(exposures)

        exposures.forEach { exposure in
            let key = ExposureKey(info: exposure)
            var durations = exposureDurations[key, default: [:]]
            let a0 = exposure.attenuationDurationThresholds[0]
            let a1 = exposure.attenuationDurationThresholds[1]
            let d0 = exposure.attenuationDurations[0]
            let d1 = min(30, exposure.attenuationDurations[0] + exposure.attenuationDurations[1])

            durations[a0] = d0
            durations[a1] = d1
            exposureDurations[key] = durations
            print("  \(key): \(durations)")
        }
    }
}
