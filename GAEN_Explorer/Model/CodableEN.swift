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
            return "\(timeInBucket)  \(totalTime)  <= \(attenuation) dB "
        }
    }

    let prevAttenuation: Int
    let attenuation: Int

    let timeInBucket: BoundedInt

    var timeInBucketString: String {
        "\(timeInBucket)"
    }

    var timeInBucketCapped: Int {
        min(timeInBucket.lb, durationCapped - prevDurationCapped)
    }

    let totalTime: BoundedInt
    let prevTotalTime: BoundedInt

    var prevDurationCapped: Int {
        min(30, prevTotalTime.lb)
    }

    var capped: Bool {
        totalTime.lb > 30
    }

    var durationCapped: Int {
        min(totalTime.lb, 30)
    }

    var attenuationLabel: String {
        if attenuation == maxAttenuation {
            return "∞"
        }
        return String(attenuation)
    }
}

struct RawAttenuationData: Codable, Hashable {
    let thresholds: [Int]
    let buckets: [BoundedInt]

    var thresholdsCSV: String {
        thresholds.map { "\($0)" }.joined(separator: ", ")
    }

    var bucketsCSV: String {
        buckets.map { "\($0)" }.joined(separator: ", ")
    }
}

// from ENExposureInfo
struct CodableExposureInfo: Codable {
    let id: UUID
    let date: Date
    var day: String {
        dayFormatter.string(from: date)
    }

    var totalDuration: BoundedInt

    var calculatedTotalDuration: BoundedInt {
        totalTime(atNoMoreThan: maxAttenuation)
    }

    let exposureInfoDuration: Int
    let totalRiskScore: ENRiskScore

    let transmissionRiskLevel: ENRiskLevel
    let attenuationValue: Int8 // attenuation risk level
    var durations: [Int: BoundedInt] // minutes
    var durationsExceeding: [Int: BoundedInt] // minutes
    var rawAnalysis: [RawAttenuationData] = []
    var analysisPasses: Int {
        rawAnalysis.count
    }

    var meaningfulDuration: BoundedInt {
        let lowAttn = totalTime(atNoMoreThan: multipassThresholds[0])
        let mediumAttn = totalTime(atNoMoreThan: multipassThresholds[1])
        let sum: BoundedInt = lowAttn + mediumAttn
        return sum / 2
    }

    func totalTime(atNoMoreThan: Int) -> BoundedInt {
        if atNoMoreThan == maxAttenuation {
            return totalDuration
        } else if atNoMoreThan == 0 {
            return BoundedInt(0)
        }
        if let v = durations[atNoMoreThan] {
            return v
        }
        let db = durations.keys.filter { $0 <= atNoMoreThan }.sorted().last!
        return durations[db]!.asLowerBound()
    }

    func totalTime(exceeding: Int) -> BoundedInt {
        if exceeding == 0 {
            return totalDuration
        } else if exceeding == maxAttenuation {
            return BoundedInt(0)
        }
        if let v = durationsExceeding[exceeding] {
            return v
        }
        let db = durations.keys.filter { $0 >= exceeding }.sorted().first!
        return durationsExceeding[db]!.asLowerBound()
    }

    //    func totalTime(atNoMoreThan: Int) -> BoundedInt {
    //        if atNoMoreThan == 0 {
    //            return 0
    //        }
    //        return max(totalTime0(atNoMoreThan: atNoMoreThan), timeInBucket(upperBound: atNoMoreThan) + totalTime(atNoMoreThan: prevThreshold(dB: atNoMoreThan)))
    //    }
    //
    //    func totalTime(exceeding: Int) -> BoundedInt {
    //        if exceeding == maxAttenuation {
    //            return 0
    //        }
    //        return max(totalTime0(exceeding: exceeding), timeInBucket(upperBound: exceeding) + totalTime(exceeding: nextThreshold(dB: exceeding)))
    //    }

    func nextThreshold(dB: Int) -> Int {
        durations.keys.filter { $0 > dB }.reduce(maxAttenuation, min)
    }

    func prevThreshold(dB: Int) -> Int {
        durations.keys.filter { $0 < dB }.reduce(0, max)
    }

    func timeInBucket(upperBound: Int) -> BoundedInt {
        let lowerBoundExclusive = prevThreshold(dB: upperBound)
        let t1 = minus(totalTime(atNoMoreThan: upperBound), totalTime(atNoMoreThan: lowerBoundExclusive))
        let t2 = minus(totalTime(exceeding: lowerBoundExclusive), totalTime(exceeding: upperBound))
        return t1.intersectionMaybe(t2)
    }

    func csvNumber(_ v: BoundedInt) -> String {
        if v == 0 {
            return ""
        }
        return v.description
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

    func cummulativeDuration(_ dB: Int) -> BoundedInt {
        let cummulativeDurationFromBelow = totalTime(atNoMoreThan: dB)
        let cummulativeDurationFromAbove = totalDuration - totalTime(exceeding: dB)
        print("cummulativeDuration( \(dB) ) = \(cummulativeDurationFromBelow), \(cummulativeDurationFromAbove)")
        return cummulativeDurationFromBelow.intersection(cummulativeDurationFromAbove)
    }

    func thresholdData(dB: Int) -> ThresholdData {
        let prevdB = prevThreshold(dB: dB)
        return ThresholdData(prevAttenuation: prevdB,
                             attenuation: dB,
                             timeInBucket: timeInBucket(upperBound: dB),
                             totalTime: totalTime(atNoMoreThan: dB),
                             prevTotalTime: totalTime(atNoMoreThan: prevdB))
    }

    var thresholdData: [ThresholdData] {
        let sortedDurations = durations.keys.sorted() + [maxAttenuation]
        return sortedDurations.map { thresholdData(dB: $0) }
    }

    mutating func merge(_ merging: CodableExposureInfo) {
        totalDuration = totalDuration.intersection(merging.totalDuration)
        durations.merge(merging.durations) { (old: BoundedInt, new: BoundedInt) in old.intersection(new) }
        durations = nonDecreasing(durations, upperBound: totalDuration)
        durationsExceeding.merge(merging.durationsExceeding) { (old: BoundedInt, new: BoundedInt) in old.intersection(new) }
        durationsExceeding = nonIncreasing(durationsExceeding, upperBound: totalDuration)
        print("After merging, got")
        print("  durations \(durations)")
        print("  durationsExceeding \(durationsExceeding)")
        print()
        rawAnalysis.append(contentsOf: merging.rawAnalysis)
    }

    init(_ info: ENExposureInfo, config: CodableExposureConfiguration) {
        self.id = UUID()
        self.date = info.date

        self.exposureInfoDuration = Int(info.duration / 60)
        self.totalRiskScore = info.totalRiskScore
        self.transmissionRiskLevel = info.transmissionRiskLevel
        self.attenuationValue = Int8(info.attenuationValue)
        let attenuationDurations = info.attenuationDurations.map { BoundedInt(Int(truncating: $0) / 60) }
        self.totalDuration = attenuationDurations[0] + attenuationDurations[1] + attenuationDurations[2]

        self.durations = [config.attenuationDurationThresholds[0]: attenuationDurations[0],
                          config.attenuationDurationThresholds[1]: attenuationDurations[0] + attenuationDurations[1]]
        self.durationsExceeding = [config.attenuationDurationThresholds[0]: attenuationDurations[1] + attenuationDurations[2],
                                   config.attenuationDurationThresholds[1]: attenuationDurations[2]]
        rawAnalysis.append(RawAttenuationData(thresholds: config.attenuationDurationThresholds, buckets: attenuationDurations))
        if true {
            print("ENExposureInfo:")
            print("  attenuationThresholds \(config.attenuationDurationThresholds)")
            print("  attenuationDurations \(attenuationDurations)")

            print("  durations \(durations)")
            print("  durationsExceeding \(durationsExceeding)")
            print()
        }
    }

    init(date: Date, transmissionRiskLevel: ENRiskLevel, totalDuration: BoundedInt = BoundedInt.unknown, durations: [Int: BoundedInt] = [:], durationsExceeding: [Int: BoundedInt] = [:]) {
        self.id = UUID()
        self.date = date
        self.totalRiskScore = 1
        self.transmissionRiskLevel = transmissionRiskLevel
        self.attenuationValue = 1
        self.totalDuration = totalDuration
        self.exposureInfoDuration = 0
        self.durations = durations
        self.durationsExceeding = durationsExceeding
    }

    let debug = false

    mutating func updateConstraints() {
        for _ in 1 ... 3 {
            if debug {
                print(totalDuration)
                print(durationsCSV)
                print(durationsExceedingCSV)
            }
            var changedDurations = false
            let keys = durations.keys.sorted()

            for dB in keys {
                let lb = totalTime(atNoMoreThan: prevThreshold(dB: dB))

                let currentValue = durations[dB]!
                let ub = totalTime(atNoMoreThan: nextThreshold(dB: dB))
                let newValue = currentValue.applyBounds(lb: lb, ub: ub)
                if debug {
                    print("durations[\(dB)] \(lb) <= \(currentValue) <= \(ub)  = \(newValue)")
                }
                if currentValue != newValue {
                    changedDurations = true
                    durations[dB] = newValue
                }
            }
            if changedDurations, debug {
                print("durations changed: \(durationsCSV)")
            }
            var changedExceeding = false
            for dB in keys.reversed() {
                let nextdB = nextThreshold(dB: dB)
                let lb = totalTime(exceeding: nextdB)
                let ub = totalTime(exceeding: prevThreshold(dB: dB))
                let currentValue = durationsExceeding[dB]!
                let newValue = currentValue.applyBounds(lb: lb, ub: ub)

                if debug {
                    print("durationsExceeding[\(dB)] \(lb) <= \(currentValue) <= \(ub)  = \(newValue)")
                }

                if currentValue != newValue {
                    changedExceeding = true
                    durationsExceeding[dB] = newValue
                }
            }
            if changedExceeding, debug {
                print("durationsExceeding changed: \(durationsExceedingCSV)")
            }

            for dB in keys {
                let prevdB = prevThreshold(dB: dB)
                let lb = totalTime(atNoMoreThan: prevThreshold(dB: dB))
                let timeInBucket = totalTime(exceeding: prevdB) - totalTime(exceeding: dB)
                let lb2 = lb + timeInBucket
                let ub = totalDuration - totalTime(exceeding: dB)
                let currentValue = durations[dB]!
                let newValue = currentValue.softApplyBounds(lb: lb2, ub: ub)

                if debug {
                    print("durations[\(dB)] \(lb2) <= \(currentValue) <= \(ub)  = \(newValue)")
                }
                if currentValue != newValue {
                    changedDurations = true
                    durations[dB] = newValue
                }
            }

            if changedDurations, debug {
                print("durations changed: \(durations)")
            }

            for dB in keys.reversed() {
                let nextdB = nextThreshold(dB: dB)
                let lb = totalTime(exceeding: nextdB)
                let timeInBucket = totalTime(atNoMoreThan: nextdB) - totalTime(atNoMoreThan: dB)
                let lb2 = lb + timeInBucket
                let ub = totalDuration - totalTime(atNoMoreThan: dB)
                let currentValue = durationsExceeding[dB]!
                let newValue = currentValue.softApplyBounds(lb: lb2, ub: ub)
                if debug {
                    print("durationsExceeding[\(dB)] \(lb2) <= \(currentValue) <= \(ub)  = \(newValue)")
                }

                if currentValue != newValue {
                    changedExceeding = true
                    durationsExceeding[dB] = newValue
                }
            }

            if changedExceeding, debug {
                print("durationsExceeding changed: \(durationsExceeding)")
            }
            if !changedDurations, !changedExceeding {
                break
            }
        }
    }

    mutating func update(thresholds: [Int], buckets: [BoundedInt]) {
        var runningTotal: BoundedInt = 0
        for i in 0 ..< thresholds.count {
            let dB = thresholds[i]
            if let oldValue = durations[dB] {
                runningTotal = intersection(oldValue, runningTotal + buckets[i])
            } else {
                runningTotal = runningTotal + buckets[i]
            }
            durations[dB] = runningTotal
        }
        runningTotal = runningTotal + buckets[thresholds.count]
        totalDuration = intersection(totalDuration, runningTotal)

        runningTotal = 0
        for i in (0 ..< thresholds.count).reversed() {
            let dB = thresholds[i]
            if let oldValue = durationsExceeding[dB] {
                runningTotal = intersection(oldValue, runningTotal + buckets[i + 1])
            } else {
                runningTotal = runningTotal + buckets[i + 1]
            }
            durationsExceeding[dB] = runningTotal
        }
        rawAnalysis.append(RawAttenuationData(thresholds: thresholds, buckets: buckets))

        updateConstraints()
        if debug {
            print("updated ENExposureInfo:")
            print("  attenuationThresholds \(thresholds)")
            print("  buckets \(buckets)")
            print("  total duration \(totalDuration)")
            print("  durations \(durations)")
            print("  durationsExceeding \(durationsExceeding)")
            print()
        }
    }

    func updated(thresholds: [Int], buckets: [BoundedInt]) -> CodableExposureInfo {
        var result = self
        result.update(thresholds: thresholds, buckets: buckets)
        return result
    }

    static let testData = [
        CodableExposureInfo(date: daysAgo(2), transmissionRiskLevel: 5)
            .updated(thresholds: [50, 64], buckets: [25, 25, 25])
            .updated(thresholds: [58, 70], buckets: [30, 25, 15]),
        CodableExposureInfo(date: daysAgo(3), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 61], buckets: [5, 10, 30])
            .updated(thresholds: [52, 58], buckets: [0, 5, 30])
            .updated(thresholds: [67, 73], buckets: [30, 25, 10])
            .updated(thresholds: [64, 70], buckets: [20, 15, 25]),
        CodableExposureInfo(date: daysAgo(4), transmissionRiskLevel: 5)
            .updated(thresholds: [55, 67], buckets: [20, 30, 30])
            .updated(thresholds: [50, 64], buckets: [5, 30, 30])
            .updated(thresholds: [61, 73], buckets: [30, 30, 30])
            .updated(thresholds: [58, 70], buckets: [25, 30, 30])
            .updated(thresholds: [52, 60], buckets: [10, 25, 30]),

        CodableExposureInfo(date: daysAgo(5), transmissionRiskLevel: 5)
            .updated(thresholds: [50, 64], buckets: [5, 5, 15]),
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
