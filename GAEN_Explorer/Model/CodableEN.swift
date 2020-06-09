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
    static let maxAttenuation = 90
    var description: String {
        thisDuration == 0 ? "" :
            "\(prevAttenuation > 0 ? "\(prevAttenuation)dB < " : "  ")\(thisDuration)min \(attenuation < 90 ? "<= \(attenuation)dB" : "")"
    }

    let prevAttenuation: Int
    let attenuation: Int
    var attenuationLabel: String {
        if attenuation == ThresholdData.maxAttenuation {
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
    var day: String {
        LocalStore.shared.dayFormatter.string(from: date)
    }

    var duration: Int8 // minutes
    var extendedDuration: Int8 // minutes
    let totalRiskScore: ENRiskScore

    let transmissionRiskLevel: ENRiskLevel
    let attenuationValue: Int8 // attenuation risk level
    let attenuationDurations: [Int] // minutes
    let attenuationDurationThresholds: [Int]
    var durations: [Int: Int] // minutes
    var meaningfulDuration: Int {
        let lowAttn = durations[50] ?? 0
        let mediumAttn = (durations[56] ?? lowAttn) - lowAttn
        return lowAttn + mediumAttn / 2
    }

    var durationsCSV: String {
        let sortedDurations = durations.sorted(by: { $0.0 < $1.0 })
        return sortedDurations.map { _, value in value == 0 ? "" : String(value) }.joined(separator: ", ")
    }

    var thresholdsCSV: String {
        let sortedDurations = durations.sorted(by: { $0.0 < $1.0 })
        return sortedDurations.map { key, _ in String(key) }.joined(separator: ", ")
    }

    var thresholdData: [ThresholdData] {
        var result: [ThresholdData] = []
        let sortedDurations = durations.sorted(by: { $0.0 < $1.0 })
        var prev: Int = 0
        var prevAnt = 0
        for (key, value) in sortedDurations {
            result.append(ThresholdData(prevAttenuation: prevAnt, attenuation: key, prevDuration: prev, cumulativeDuration: value))
            prev = value
            prevAnt = key
        }
        result.append(ThresholdData(prevAttenuation: prevAnt, attenuation: ThresholdData.maxAttenuation, prevDuration: prev, cumulativeDuration: max(prev, Int(duration))))
        return result
    }

    mutating func merge(_ merging: CodableExposureInfo) {
        extendedDuration = max(extendedDuration, merging.extendedDuration)
        duration = max(duration, merging.duration)
        durations.merge(merging.durations) { old, _ in old }
    }

    init(_ info: ENExposureInfo, config: CodableExposureConfiguration) {
        self.id = UUID()
        self.date = info.date

        self.totalRiskScore = info.totalRiskScore
        self.transmissionRiskLevel = info.transmissionRiskLevel
        self.attenuationValue = Int8(info.attenuationValue)
        self.attenuationDurations = info.attenuationDurations.map { Int(truncating: $0) / 60 }
        self.duration = Int8(info.duration / 60)
        self.extendedDuration = Int8(attenuationDurations[0] + attenuationDurations[1] + attenuationDurations[2])
        self.attenuationDurationThresholds = config.attenuationDurationThresholds

        self.durations = [config.attenuationDurationThresholds[0]: attenuationDurations[0],
                          config.attenuationDurationThresholds[1]: min(30, attenuationDurations[0] + attenuationDurations[1])]
        if false {
            print("ENExposureInfo:")
            print("  transmissionRiskLevel \(transmissionRiskLevel)")
            print("  duration \(duration)")

            print("  attenuationValue \(attenuationValue)")
            print("  attenuationDurations \(attenuationDurations)")
            print("  durations \(durations)")

            print()
        }
    }

    // testdata
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
        self.extendedDuration = Int8(attenuationDurations[0] + attenuationDurations[1] + attenuationDurations[2])
    }

    init(
        date: Date,
        duration: Int8,
        totalRiskScore: ENRiskScore,
        transmissionRiskLevel: ENRiskLevel,
        attenuationValue: Int8,
        durations: [Int: Int]
    ) {
        self.id = UUID()
        self.date = date
        self.duration = duration
        self.totalRiskScore = totalRiskScore
        self.transmissionRiskLevel = transmissionRiskLevel
        self.attenuationValue = attenuationValue
        let config = CodableExposureConfiguration.shared
        let a0 = durations[config.attenuationDurationThresholds[0]]!
        let a1 = durations[config.attenuationDurationThresholds[1]]!
        self.attenuationDurations = [a0, a1 - a0, 30]

        self.attenuationDurationThresholds = config.attenuationDurationThresholds
        self.durations = durations
        self.extendedDuration = Int8(attenuationDurations[0] + attenuationDurations[1] + attenuationDurations[2])
    }

    static let testData = [
        CodableExposureInfo(date: daysAgo(3), duration: 30, totalRiskScore: ENRiskScore(42), transmissionRiskLevel: 5, attenuationValue: 4, durations: [44: 0, 47: 5, 50: 5, 53: 15, 56: 20, 59: 20, 62: 25, 65: 30]),

        CodableExposureInfo(date: daysAgo(4), duration: 20, totalRiskScore: ENRiskScore(42), transmissionRiskLevel: 5, attenuationValue: 5, attenuationDurations: [10, 5, 5]),
    ]
}

// from ENTemporaryExposureKey
struct CodableDiagnosisKey: Codable, Equatable {
    let keyData: Data
    let rollingPeriod: ENIntervalNumber
    let rollingStartNumber: ENIntervalNumber
    var transmissionRiskLevel: ENRiskLevel = 0
    let republicationSecret: UInt64? = nil
    init(_ key: ENTemporaryExposureKey) {
        self.keyData = key.keyData
        self.rollingPeriod = key.rollingPeriod
        self.rollingStartNumber = key.rollingStartNumber
        self.transmissionRiskLevel = key.transmissionRiskLevel
    }

    static let rollingPeriod: ENIntervalNumber = 144
    init(randomFromDaysAgo daysAgo: UInt32) {
        let dNumber = UInt32(Date().timeIntervalSince1970 / 24 / 60 / 60)
        var keyData = Data(count: 16)
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 16, $0)
        }
        self.keyData = keyData
        if result != errSecSuccess {
            print("random failed \(result)")
        }

        self.rollingPeriod = Self.rollingPeriod
        self.rollingStartNumber = (dNumber - daysAgo) * Self.rollingPeriod
        self.transmissionRiskLevel = 0
    }

    mutating func setTransmissionRiskLevel(transmissionRiskLevel: ENRiskLevel) {
        self.transmissionRiskLevel = transmissionRiskLevel
    }

    static func exportToURL(packages: [PackagedKeys]) -> URL? {
        guard let encoded = try? JSONEncoder().encode(packages) else { return nil }

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
        "attenuationLevelValues":[2,7,1,8, 3,6,5,4],
        "daysSinceLastExposureLevelValues":[1, 1, 1, 1, 1, 1, 1, 1],
        "durationLevelValues":[1, 1, 1, 1, 1, 1, 1, 1],
        "transmissionRiskLevelValues":[1, 1, 1, 1, 1, 1, 1, 1],
        "attenuationDurationThresholds": [50, 56]}
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
