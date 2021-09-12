//
//  CodableEN.swift
//  GAEN_Explorer
//
//  Created by Bill Pugh on 5/11/20.
///

import ExposureNotification
import Foundation

let attenuationDurationThresholdsKey = "attenuationDurationThresholds"
let maxAttenuation = 99
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
        min(timeInBucket.ub, durationCapped - prevDurationCapped)
    }

    let totalTime: BoundedInt
    let prevTotalTime: BoundedInt

    var prevDurationCapped: Int {
        min(30, prevTotalTime.ub)
    }

    var capped: Bool {
        totalTime.lb > 30
    }

    var durationCapped: Int {
        min(totalTime.ub, 30)
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
    let bucket: [Int]

    var thresholdsCSV: String {
        thresholds.map { "\($0)" }.joined(separator: ", ")
    }

    var bucketsCSV: String {
        bucket.map { "\($0)" }.joined(separator: ", ")
    }
}

// from ENExposureInfo
struct CodableExposureInfo: Codable {
    let id: UUID
    let date: Date
    var day: String {
        dayFormatter.string(from: date)
    }

    static var cvsTestingMode: Bool = false

    var totalDuration: BoundedInt
    var duration: BoundedInt

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

    var needsReanalysis: Bool = false

    var meaningfulDuration: BoundedInt {
        let lowAttn = totalTime(atNoMoreThan: lowerThresholdMeaningful)
        let mediumAttn = totalTime(atNoMoreThan: upperThresholdMeaningful)
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
            return v.applyBounds(ub: totalDuration)
        }
        let db = durations.keys.filter { $0 <= atNoMoreThan }.sorted().last!
        return durations[db]!.asLowerBound().applyBounds(ub: totalDuration)
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
        if CodableExposureInfo.cvsTestingMode {
            if v == 0 {
                return ""
            }
            return v.description
        }
        return "\(v.ub)"
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

    func cumulativeDuration(_ dB: Int) -> BoundedInt {
        let cumulativeDurationFromBelow = totalTime(atNoMoreThan: dB)
        let cumulativeDurationFromAbove = totalDuration - totalTime(exceeding: dB)
        print("cumulativeDuration( \(dB) ) = \(cumulativeDurationFromBelow), \(cumulativeDurationFromAbove)")
        return cumulativeDurationFromBelow.intersection(cumulativeDurationFromAbove).applyBounds(ub: totalDuration)
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
        let firstDb = durations.filter { _, v in v > 0 }.keys.sorted().first ?? maxAttenuation
        let sortedDurations = durations.keys.filter { $0 >= firstDb }.sorted() + [maxAttenuation]
        return sortedDurations.map { thresholdData(dB: $0) }
    }

    func thresholdData(max: Int) -> [ThresholdData] {
        let keys = durations.keys.sorted()
        let excess = keys.count + 1 - max
        if excess > 0 {
            let start = (excess + 1) / 2
            let end = keys.count - (excess - start)
            return (keys[start ..< end] + [maxAttenuation]).map { thresholdData(dB: $0) }
        }
        return (keys + [maxAttenuation]).map { thresholdData(dB: $0) }
    }

    mutating func merge(_ merging: CodableExposureInfo) {
        duration = merging.duration.intersection(duration)
        rawAnalysis.append(contentsOf: merging.rawAnalysis)
        needsReanalysis = true
    }

    init(_ info: ENExposureInfo, trueDuration: TimeInterval?, config: CodableExposureConfiguration) {
        self.id = UUID()
        self.date = info.date

        print("ExposureInfo.time since 1970 = \(info.date.timeIntervalSince1970)")
        print("ExposureInfo.duration = \(info.duration)")
        print("ExposureInfo.attenuationDurations = \(info.attenuationDurations)")
        print("ExposureInfo.totalRiskScore = \(info.totalRiskScore)")
        print("ExposureInfo.totalRiskScoreFullRange = \(info.totalRiskScoreFullRange)")
        print("ExposureInfo.attenuationValue = \(info.attenuationValue)")
        print("ExposureInfo.transmissionRiskLevel = \(info.transmissionRiskLevel)")

        self.duration = trueDuration == nil ? BoundedInt(Int(info.duration / 60)) :
            BoundedInt(Int((trueDuration!) / 60), Int((trueDuration! + 120 + 59) / 60))
        self.exposureInfoDuration = Int(info.duration / 60)
        self.totalRiskScore = info.totalRiskScore
        self.transmissionRiskLevel = info.transmissionRiskLevel
        self.attenuationValue = Int8(info.attenuationValue)
        self.totalDuration = duration
        self.durations = [:]
        self.durationsExceeding = [:]
        let attenuationDurations = info.attenuationDurations.map { (Int(truncating: $0) / 60) }

        let ra = RawAttenuationData(thresholds: config.attenuationDurationThresholds, bucket: attenuationDurations)
        rawAnalysis.append(ra)
        incorporateDurations(ra)
        self.needsReanalysis = true
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
        self.duration = totalDuration
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

    func update(_ dict: inout [Int: BoundedInt], dB: Int, newValue: BoundedInt) {
        dict[dB] = newValue.intersection(dict[dB])
    }

    mutating func incorporateDurations(_ ra: RawAttenuationData) {
        let bBucket = ra.bucket.map { BoundedInt($0) }
        let bBucketSum = bBucket.reduce(BoundedInt(0), +)

        totalDuration = totalDuration.minimum(bBucketSum)
        var bBucket2: [BoundedInt] = []
        for i in 0 ... ra.thresholds.count {
            var time = BoundedInt(0)
            for j in 0 ... ra.thresholds.count {
                if i != j {
                    time = time + bBucket[j]
                }
            }
            let v = bBucket[i].intersection(totalDuration - time).applyBounds(ub: totalDuration)
            bBucket2.append(v)
        }

        for i in 0 ..< ra.thresholds.count {
            update(&durations, dB: ra.thresholds[i], newValue: bBucket2[0 ... i].reduce(BoundedInt.Zero, +))

            update(&durationsExceeding, dB: ra.thresholds[i], newValue: bBucket2[i + 1 ... ra.thresholds.count].reduce(BoundedInt.Zero, +))
        }
    }

    mutating func reanalyze() {
        if !needsReanalysis {
            print("skipping reanalysis")
            return
        }
        needsReanalysis = false
        durations.removeAll()
        durationsExceeding.removeAll()
        totalDuration = duration
        for ra in rawAnalysis { incorporateDurations(ra) }
        updateConstraints()
    }

    @discardableResult mutating func update(duration: BoundedInt? = nil, thresholds: [Int], buckets intBuckets: [Int]) -> CodableExposureInfo {
        let bucketSum = intBuckets.map { BoundedInt($0) }.reduce(BoundedInt(0),+)
        let dduration: BoundedInt =
            duration != nil ? duration! : bucketSum

        self.duration = self.duration.minimum(dduration)
        rawAnalysis.append(RawAttenuationData(thresholds: thresholds, bucket: intBuckets))

        needsReanalysis = true
        reanalyze()
        return self
    }

    @discardableResult mutating func updateAndDump(duration: BoundedInt? = nil, thresholds: [Int], buckets intBuckets: [Int]) -> CodableExposureInfo {
        update(duration: duration, thresholds: thresholds, buckets: intBuckets)
        print("Updated with \(thresholds)  \(intBuckets)")
        print(sortedThresholds)

        print(duration)
        print(totalDuration)
        print(durationsCSV)
        print(durationsExceedingCSV)
        print(timeInBucketCSV)
        print()
        return self
    }

    func updated(duration: BoundedInt? = nil, thresholds: [Int], buckets: [Int]) -> CodableExposureInfo {
        var result = self
        result.duration = result.duration.intersection(duration)
        result.update(thresholds: thresholds, buckets: buckets)
        return result
    }

    static func quantizeScans(_ inBucket: [(key: Int, value: Int)]) -> [Int] {
        let scanQuantum = 2.63
        let threshold = scanQuantum / 2
        var residue = 0.0
        var result: [Int] = []
        inBucket.sorted { $0.key < $1.key }.forEach { dB, time in
            residue = Double(time)
            while residue > threshold, dB < maxAttenuation {
                residue -= scanQuantum
                result.append(dB)
            }
        }
        return result
    }

    func csvFormat(owner: String, from userName: String, pair: String) -> [String] {
        let timeInBuckets = Dictionary(uniqueKeysWithValues: sortedThresholds.map { ($0, timeInBucket(upperBound: $0).ub) }).sorted { $0.key < $1.key }
        let timeLeqBuckets = Dictionary(uniqueKeysWithValues: sortedThresholds.map { ($0, cumulativeDuration($0).ub) }).sorted { $0.key < $1.key }.filter { $0.value > 0 }

        let result =
            ["""
            exposure, \(owner), \(userName),  \(pair), \(day), cumulative,  \(durationsCSV)
            exposure, \(owner), \(userName),  \(pair), \(day), inBucket,  \(timeInBucketCSV)
            exposure, \(owner), \(userName),  \(pair), \(day), erv,  \(totalRiskScore), av, \(attenuationValue), dur, \(exposureInfoDuration)
            """]
            + (1 ... rawAnalysis.count).map { pass in
                let ra = rawAnalysis[pass - 1]
                return "rawAnalysis, \(owner), \(userName),  \(pair), \(day), \(pass),  \(ra.thresholdsCSV),  \(ra.bucketsCSV)"
            }
        let scans: [Int] = CodableExposureInfo.quantizeScans(timeInBuckets)
        let leqsCSV = timeLeqBuckets.map { "leq, \(owner), \(userName), \(pair), \(day),  \($0), \($1)" }
        let scanCSV = scans.map { "scan, \(owner), \(userName), \(pair), \(day),  \($0)" }
        return result + leqsCSV + scanCSV
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
    init(_ key: ENTemporaryExposureKey) {
        self.keyData = key.keyData
        self.rollingPeriod = key.rollingPeriod
        self.rollingStartNumber = key.rollingStartNumber
        self.transmissionRiskLevel = key.transmissionRiskLevel
    }

    var keyString: String {
        let encoded = try! JSONEncoder().encode(keyData)
        return String(data: encoded, encoding: .utf8)!
    }

    static let rollingPeriodForOneDay: ENIntervalNumber = 144
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

        self.rollingPeriod = Self.rollingPeriodForOneDay
        self.rollingStartNumber = (dNumber - daysAgo) * Self.rollingPeriodForOneDay
        self.transmissionRiskLevel = 0
    }

    mutating func setTransmissionRiskLevel(transmissionRiskLevel: ENRiskLevel) {
        self.transmissionRiskLevel = transmissionRiskLevel
    }

    static func exportToURL(packages: [PackagedKeys]) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        guard let encoded = try? encoder.encode(packages) else { return nil }

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
        {"minimumRiskScore":255,
        "attenuationLevelValues":[1, 1, 1, 1, 1, 1, 1, 1],
        "daysSinceLastExposureLevelValues":[1, 1, 1, 1, 1, 1, 1, 1],
        "durationLevelValues":[0,0,0,0,4,5,8,8],
        "transmissionRiskLevelValues":[1, 1, 1, 1, 1, 1, 1, 1],
        "attenuationDurationThresholds": [53, 66]}
        """
    }

    static func getCodableExposureConfiguration() -> CodableExposureConfiguration {
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
        exposureConfiguration.attenuationDurationThresholds = attenuationDurationThresholds as [NSNumber]

        var infectiousnessForDaysSinceOnsetOfSymptoms = [Int: Int]()

        infectiousnessForDaysSinceOnsetOfSymptoms[13] = Int(ENInfectiousness.standard.rawValue)
        infectiousnessForDaysSinceOnsetOfSymptoms[-1] = Int(ENInfectiousness.high.rawValue)
        for day in -3 ... 10 {
            infectiousnessForDaysSinceOnsetOfSymptoms[day] = Int(ENInfectiousness.standard.rawValue)
        }
        for day in -1 ... 3 {
            infectiousnessForDaysSinceOnsetOfSymptoms[day] = Int(ENInfectiousness.high.rawValue)
        }
        infectiousnessForDaysSinceOnsetOfSymptoms[ENDaysSinceOnsetOfSymptomsUnknown] = Int(ENInfectiousness.standard.rawValue)

        print("ENDaysSinceOnsetOfSymptomsUnknown \(ENDaysSinceOnsetOfSymptomsUnknown)")
        print("infectiousnessForDaysSinceOnsetOfSymptoms \(infectiousnessForDaysSinceOnsetOfSymptoms)")

        exposureConfiguration.infectiousnessForDaysSinceOnsetOfSymptoms = infectiousnessForDaysSinceOnsetOfSymptoms as [NSNumber: NSNumber]

        print("exposureConfiguration.infectiousnessForDaysSinceOnsetOfSymptoms = \(exposureConfiguration.infectiousnessForDaysSinceOnsetOfSymptoms)")
        exposureConfiguration.immediateDurationWeight = 100
        exposureConfiguration.nearDurationWeight = 100
        exposureConfiguration.mediumDurationWeight = 100
        exposureConfiguration.otherDurationWeight = 100
        exposureConfiguration.daysSinceLastExposureThreshold = 14

        exposureConfiguration.infectiousnessStandardWeight = 100
        exposureConfiguration.infectiousnessHighWeight = 100
        exposureConfiguration.reportTypeConfirmedTestWeight = 100
        exposureConfiguration.reportTypeConfirmedClinicalDiagnosisWeight = 47
        exposureConfiguration.reportTypeSelfReportedWeight = 37
        exposureConfiguration.reportTypeRecursiveWeight = 23
        exposureConfiguration.reportTypeNoneMap = .confirmedClinicalDiagnosis
        print("exposureConfiguration.description: \(exposureConfiguration.description)")
        return exposureConfiguration
    }
}
