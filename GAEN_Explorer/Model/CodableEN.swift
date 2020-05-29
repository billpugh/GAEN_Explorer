//
//  CodableEN.swift
//  GAEN_Explorer
//
//  Created by Bill Pugh on 5/11/20.
///

import ExposureNotification
import Foundation

let attenuationDurationThresholdsKey = "attenuationDurationThresholds"

struct ThresholdData: Hashable, CustomStringConvertible {
    var description: String {
        "\(prevAttenuation > 0 ? "\(prevAttenuation)dB < " : "  ")\(thisDuration)min \(attenuation < 90 ? "<= \(attenuation)dB" : "")"
    }

    let prevAttenuation: Int
    let attenuation: Int
    var attenuationLabel: String {
        if attenuation == 90 {
            return "∞"
        }
        return String(attenuation)
    }

    let prevDuration: Int
    let cumulativeDuration: Int
    var thisDuration: Int {
        cumulativeDuration - prevDuration
    }
}

// from ENExposureInfo
struct CodableExposureInfo: Codable {
    let id: UUID
    let date: Date
    let duration: Int8 // minutes
    let totalRiskScore: ENRiskScore

    let transmissionRiskLevel: ENRiskLevel
    let attenuationValue: Int8 // attenuation risk level
    let attenuationDurations: [Int] // minutes
    let attenuationDurationThresholds: [Int]
    var durations: [Int: Int] // minutes

    var thresholdData: [ThresholdData] {
        var result: [ThresholdData] = []
        let sortedDurations = durations.sorted(by: { $0.0 < $1.0 })
        var prev: Int = 0
        var prevAnt = 0
        for (key, value) in sortedDurations {
            let cumulative = min(30, prev + value)
            result.append(ThresholdData(prevAttenuation: prevAnt, attenuation: key, prevDuration: prev, cumulativeDuration: cumulative))
            prev = cumulative
            prevAnt = key
        }
        result.append(ThresholdData(prevAttenuation: prevAnt, attenuation: 90, prevDuration: prev, cumulativeDuration: Int(duration)))
        return result
    }

    init(_ base: CodableExposureInfo, merging: CodableExposureInfo) {
        self.id = base.id
        self.date = base.date

        self.duration = base.duration
        self.totalRiskScore = base.totalRiskScore
        self.transmissionRiskLevel = base.transmissionRiskLevel
        self.attenuationValue = base.attenuationValue
        self.attenuationDurations = base.attenuationDurations
        self.attenuationDurationThresholds = base.attenuationDurations
        self.durations = base.durations.merging(merging.durations) { old, _ in old }
    }

    init(_ info: ENExposureInfo, config: CodableExposureConfiguration) {
        self.id = UUID()
        self.date = info.date

        self.duration = Int8(info.duration / 60)
        self.totalRiskScore = info.totalRiskScore
        self.transmissionRiskLevel = info.transmissionRiskLevel
        self.attenuationValue = Int8(info.attenuationValue)
        self.attenuationDurations = info.attenuationDurations.map { Int(truncating: $0) / 60 }
        self.attenuationDurationThresholds = config.attenuationDurationThresholds

        self.durations = [config.attenuationDurationThresholds[0]: attenuationDurations[0],
                          config.attenuationDurationThresholds[1]: min(30, attenuationDurations[0] + attenuationDurations[1])]
        print("ENExposureInfo:")
        print("  transmissionRiskLevel \(transmissionRiskLevel)")
        print("  duration \(duration)")

        print("  attenuationValue \(attenuationValue)")
        print("  attenuationDurations \(attenuationDurations)")
        print("  durations \(durations)")

        print()
    }

    init(
        date: Date,
        duration: Int8,
        totalRiskScore: ENRiskScore,
        transmissionRiskLevel: ENRiskLevel,
        attenuationValue: Int8,
        attenuationDurations: [Int]
    ) {
        self.id = UUID()
        self.date = date
        self.duration = duration
        self.totalRiskScore = totalRiskScore
        self.transmissionRiskLevel = transmissionRiskLevel
        self.attenuationValue = attenuationValue
        self.attenuationDurations = attenuationDurations
        let config = CodableExposureConfiguration.shared
        self.attenuationDurationThresholds = config.attenuationDurationThresholds
        self.durations = [config.attenuationDurationThresholds[0]: attenuationDurations[0],
                          config.attenuationDurationThresholds[1]: attenuationDurations[1]]
    }

    static let testData = [
        CodableExposureInfo(date: daysAgo(3), duration: 25, totalRiskScore: ENRiskScore(42), transmissionRiskLevel: 5, attenuationValue: 4, attenuationDurations: [5, 10, 10]),
        CodableExposureInfo(date: daysAgo(4), duration: 20, totalRiskScore: ENRiskScore(42), transmissionRiskLevel: 5, attenuationValue: 5, attenuationDurations: [10, 5, 5]),
    ]
}

// from ENTemporaryExposureKey
struct CodableDiagnosisKey: Codable, Equatable {
    let keyData: Data
    let rollingPeriod: ENIntervalNumber
    let rollingStartNumber: ENIntervalNumber
    let transmissionRiskLevel: ENRiskLevel
    let republicationSecret: UInt64? = nil
    init(_ key: ENTemporaryExposureKey, tRiskLevel: ENRiskLevel) {
        self.keyData = key.keyData
        self.rollingPeriod = key.rollingPeriod
        self.rollingStartNumber = key.rollingStartNumber
        self.transmissionRiskLevel = tRiskLevel
        // self.republicationSecret = UInt64.random(in: UInt64.min ... UInt64.max)
    }

    static func exportToURL(package: PackagedKeys) -> URL? {
        guard let encoded = try? JSONEncoder().encode(package) else { return nil }

        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first

        guard let path = documents?.appendingPathComponent("test.diagk") else {
            return nil
        }

        do {
            print(path)
            try encoded.write(to: path, options: .atomicWrite)
            return path
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
}

// ENExposureConfiguration
struct CodableExposureConfiguration: Codable {
    static let attenuationLevelHigh: NSNumber = 0
    static let attenuationLevelMedium: NSNumber = 3
    static let attenuationLevelLow: NSNumber = 6

    let minimumRiskScore: ENRiskScore
    let attenuationLevelValues: [ENRiskLevelValue]
    let daysSinceLastExposureLevelValues: [ENRiskLevelValue]
    let durationLevelValues: [ENRiskLevelValue]
    let transmissionRiskLevelValues: [ENRiskLevelValue]
    var attenuationDurationThresholds: [Int]

    static func getExposureConfigurationString() -> String {
        """
        {"minimumRiskScore":0,
        "attenuationLevelValues":[1,2,3,4,5,6,7,8],
        "daysSinceLastExposureLevelValues":[1, 1, 1, 1, 1, 1, 1, 1],
        "durationLevelValues":[1, 1, 1, 1, 1, 1, 1, 1],
        "transmissionRiskLevelValues":[1, 1, 1, 1, 1, 1, 1, 1],
        "attenuationDurationThresholds": [50, 55]}
        """
    }

    private static func getCodableExposureConfiguration() -> CodableExposureConfiguration {
        let dataFromServer = getExposureConfigurationString().data(using: .utf8)!

        let codableExposureConfiguration = try! JSONDecoder().decode(CodableExposureConfiguration.self, from: dataFromServer)
        return codableExposureConfiguration
    }

    static func getCodableExposureConfiguration(pass: Int) -> CodableExposureConfiguration {
        var config = getCodableExposureConfiguration()
        config.attenuationDurationThresholds = getAttenuationDurationThresholds(pass: pass)
        return config
    }

    static let shared = getCodableExposureConfiguration()

    func asExposureConfiguration() -> ENExposureConfiguration {
        let exposureConfiguration = ENExposureConfiguration()
        exposureConfiguration.minimumRiskScore = minimumRiskScore
        exposureConfiguration.attenuationLevelValues = attenuationLevelValues as [NSNumber]
        exposureConfiguration.daysSinceLastExposureLevelValues = daysSinceLastExposureLevelValues as [NSNumber]

        exposureConfiguration.durationLevelValues = durationLevelValues as [NSNumber]
        exposureConfiguration.transmissionRiskLevelValues = transmissionRiskLevelValues as [NSNumber]
        exposureConfiguration.metadata = ["attenuationDurationThresholds": attenuationDurationThresholds]
        return exposureConfiguration
    }
}
