//
//  CodableEN.swift
//  GAEN_Explorer
//
//  Created by Bill Pugh on 5/11/20.
///

import ExposureNotification
import Foundation

let attenuationDurationThresholdsKey = "attenuationDurationThresholds"
let maxAttenuation = 90
struct ThresholdData: Hashable, CustomStringConvertible {
    var description: String {
        if true {
            return "\(prevAttenuation) dB <  \(thisDuration) \(maxThisDuration) \(cumulativeDuration):\(durationDebug ?? -1) \(maxCumulativeDuration) \(exceedingDuration):\(durationExceedingDebug ?? -1) <= \(attenuation) dB "
        }
        //        thisDuration == 0 ? "" :
        //            "\(prevAttenuation > 0 ? "\(prevAttenuation)dB < " : "  ")\(thisDuration)min \(attenuation < maxAttenuation ? "<= \(attenuation)dB" : "")"
    }

    let prevAttenuation: Int
    let attenuation: Int

    let thisDuration: Int

    var thisDurationString: String {
        if thisDuration >= 10 {
            return "\(thisDuration)"
        }
        return "  \(thisDuration)"
    }

    var thisDurationCapped: Int {
        min(thisDuration, cumulativeDurationCapped - prevCumulativeDurationCapped)
    }

    let cumulativeDuration: Int
    let prevCumulativeDuration: Int
    let maxCumulativeDuration: Int

    var maxThisDuration: Int {
        maxCumulativeDuration - cumulativeDuration + thisDuration
    }

    var prevCumulativeDurationCapped: Int {
        min(30, prevCumulativeDuration)
    }

    let exceedingDuration: Int

    var capped: Bool {
        cumulativeDuration > 30
    }

    let durationDebug: Int?
    let durationExceedingDebug: Int?
    var cumulativeDurationCapped: Int {
        min(cumulativeDuration, 30)
    }

    var attenuationLabel: String {
        if attenuation == maxAttenuation {
            return "∞"
        }
        return String(attenuation)
    }
}

struct RawAttenuationData: Codable {
    let thresholds: [Int]
    let durations: [Int]
}

// from ENExposureInfo
struct CodableExposureInfo: Codable {
    let id: UUID
    let date: Date
    var day: String {
        dayFormatter.string(from: date)
    }

    var totalDuration: Int

    var calculatedTotalDuration: Int {
        totalTime(atNoMoreThan: maxAttenuation)
    }

    let exposureInfoDuration: Int
    let totalRiskScore: ENRiskScore

    let transmissionRiskLevel: ENRiskLevel
    let attenuationValue: Int8 // attenuation risk level
    var durations: [Int: Int] // minutes
    var durationsExceeding: [Int: Int] // minutes
    var rawAnalysis: [RawAttenuationData] = []
    var meaningfulDuration: Int {
        let lowAttn = totalTime(atNoMoreThan: multipassThresholds[0])
        let mediumAttn = totalTime(atNoMoreThan: multipassThresholds[1]) - lowAttn
        return lowAttn + mediumAttn / 2
    }

    func totalTime0(atNoMoreThan: Int) -> Int {
        if atNoMoreThan == maxAttenuation {
            return totalDuration
        } else if atNoMoreThan == 0 {
            return 0
        }
        return durations.map { k, v in
            k <= atNoMoreThan ? v : 0
        }.reduce(0, max)
    }

    func totalTime0(exceeding: Int) -> Int {
        if exceeding == 0 {
            return totalDuration
        } else if exceeding == maxAttenuation {
            return 0
        }
        return durationsExceeding.map { k, v in
            k >= exceeding ? v : 0
        }.reduce(0, max)
    }

    func totalTime(atNoMoreThan: Int) -> Int {
        if atNoMoreThan == 0 {
            return 0
        }
        return max(totalTime0(atNoMoreThan: atNoMoreThan), timeInBucket(upperBound: atNoMoreThan) + totalTime(atNoMoreThan: prevThreshold(dB: atNoMoreThan)))
    }

    func totalTime(exceeding: Int) -> Int {
        if exceeding == maxAttenuation {
            return 0
        }
        return max(totalTime0(exceeding: exceeding), timeInBucket(upperBound: exceeding) + totalTime(exceeding: nextThreshold(dB: exceeding)))
    }

    func nextThreshold(dB: Int) -> Int {
        durations.keys.filter { $0 > dB }.reduce(maxAttenuation, min)
    }

    func prevThreshold(dB: Int) -> Int {
        durations.keys.filter { $0 < dB }.reduce(0, max)
    }

    func timeInBucket(upperBound: Int) -> Int {
        let lowerBoundExclusive = prevThreshold(dB: upperBound)
        let t1 = totalTime0(atNoMoreThan: lowerBoundExclusive) >= 30 ? 0 : totalTime0(atNoMoreThan: upperBound) - totalTime0(atNoMoreThan: lowerBoundExclusive)
        let t2 = totalTime0(exceeding: upperBound) >= 30 ? 0 : totalTime0(exceeding: lowerBoundExclusive) - totalTime0(exceeding: upperBound)
        return max(t1, t2)
    }

    func csvNumber(_ v: Int) -> String {
        if v == 0 {
            return ""
        }
        return String(v)
    }

    var sortedThresholds: [Int] {
        durations.keys.sorted() + [maxAttenuation]
    }

    var durationsCSV: String {
        sortedThresholds.map { csvNumber(totalTime(atNoMoreThan: $0)) }.joined(separator: ", ")
    }

    var durationsExceedingCSV: String {
        sortedThresholds.map { csvNumber(totalTime(exceeding: $0)) }.joined(separator: ", ")
    }

    var timeInBucketCSV: String {
        sortedThresholds.map { csvNumber(timeInBucket(upperBound: $0)) }.joined(separator: ", ")
    }

    var thresholdsCSV: String {
        durations.keys.sorted().map { String($0) }.joined(separator: ", ")
    }

    func thresholdData(dB: Int) -> ThresholdData {
        let prevdB = prevThreshold(dB: dB)
        let nextdB = nextThreshold(dB: dB)
        let cummulativeDuration = totalTime(atNoMoreThan: dB)
        return ThresholdData(prevAttenuation: prevdB,
                             attenuation: dB,
                             thisDuration: timeInBucket(upperBound: dB),
                             cumulativeDuration: cummulativeDuration,
                             prevCumulativeDuration: totalTime(atNoMoreThan: prevdB),
                             maxCumulativeDuration: max(cummulativeDuration,
                                                        totalTime(atNoMoreThan: nextdB) - timeInBucket(upperBound: nextdB)),
                             exceedingDuration: totalTime(exceeding: dB),
                             durationDebug: durations[dB],
                             durationExceedingDebug: durationsExceeding[dB])
    }

    var thresholdData: [ThresholdData] {
        let sortedDurations = durations.keys.sorted() + [maxAttenuation]
        return sortedDurations.map { thresholdData(dB: $0) }
    }

    mutating func merge(_ merging: CodableExposureInfo) {
        totalDuration = max(totalDuration, merging.totalDuration)
        durations.merge(merging.durations) { old, _ in old }
        durationsExceeding.merge(merging.durationsExceeding) { old, _ in old }
        rawAnalysis.append(contentsOf: merging.rawAnalysis)
    }

    init(_ info: ENExposureInfo, config: CodableExposureConfiguration) {
        self.id = UUID()
        self.date = info.date

        self.exposureInfoDuration = Int(info.duration / 60)
        self.totalRiskScore = info.totalRiskScore
        self.transmissionRiskLevel = info.transmissionRiskLevel
        self.attenuationValue = Int8(info.attenuationValue)
        let attenuationDurations = info.attenuationDurations.map { Int(truncating: $0) / 60 }
        self.totalDuration = max(Int(info.duration / 60), attenuationDurations[0] + attenuationDurations[1] + attenuationDurations[2])

        self.durations = [config.attenuationDurationThresholds[0]: attenuationDurations[0],
                          config.attenuationDurationThresholds[1]: attenuationDurations[0] + attenuationDurations[1]]
        self.durationsExceeding = [config.attenuationDurationThresholds[0]: attenuationDurations[1] + attenuationDurations[2],
                                   config.attenuationDurationThresholds[1]: attenuationDurations[2]]
        rawAnalysis.append(RawAttenuationData(thresholds: config.attenuationDurationThresholds, durations: attenuationDurations))
        if true {
            print("ENExposureInfo:")
            print("  attenuationDurations \(attenuationDurations)")

            print("  durations \(durations)")
            print("  durationsExceeding \(durationsExceeding)")
            print()
        }
    }

    init(
        date: Date,
        duration: Int,
        totalRiskScore: ENRiskScore,
        transmissionRiskLevel: ENRiskLevel,
        attenuationValue: Int8,
        durations: [Int: Int],
        durationsExceeding _: [Int: Int]? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.totalRiskScore = totalRiskScore
        self.transmissionRiskLevel = transmissionRiskLevel
        self.attenuationValue = attenuationValue
        self.durations = durations
        self.totalDuration = duration
        self.exposureInfoDuration = min(30, duration)
        self.durationsExceeding =
            Dictionary(uniqueKeysWithValues:
                durations.map { key, value in (key, duration - value) })
    }

    static let testData = [
        CodableExposureInfo(date: daysAgo(3), duration: 75, totalRiskScore: ENRiskScore(42), transmissionRiskLevel: 5, attenuationValue: 4,
                            durations: [50: 10, 55: 15, 64: 40, 67: 45],
                            durationsExceeding: [67: 30, 64: 30, 55: 60, 50: 60]),

        CodableExposureInfo(date: daysAgo(4), duration: 35, totalRiskScore: ENRiskScore(42), transmissionRiskLevel: 5, attenuationValue: 5, durations: [44: 0, 47: 0, 50: 10, 53: 10, 56: 20, 59: 20, 62: 25, 65: 30]),
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
