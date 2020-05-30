//
//  LocalStores.swift
//  GAEN_Explorer
//
//  Created by Bill on 5/24/20.
//

import Foundation

struct PackagedKeys: Codable {
    var userName: String
    var date: Date
    var keys: [CodableDiagnosisKey]
}

private let goDeeperQueue = DispatchQueue(label: "com.ninjamonkeycoders.gaen.goDeeper", attributes: .concurrent)

struct BatchExposureInfo: Codable {
    static let exposureDateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    static let dateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"

        return formatter
    }()

    let userName: String
    let dateKeysSent: Date
    let dateProcessed: Date
    let keys: [CodableDiagnosisKey]
    var keysChecked: Int {
        keys.count
    }

    var memo: String?
    var analysisPasses = 1
    var config: CodableExposureConfiguration?
    var someConfig: CodableExposureConfiguration {
        if let c = config {
            return c
        }
        return CodableExposureConfiguration.shared
    }

    var exposures: [CodableExposureInfo]
    var memoConfig: String {
        if let m = memo {
            return "memo: \(m)"
        }
        if let c = config {
            return "attenuationDurationThresholds: \(c.attenuationDurationThresholds[0])/\(c.attenuationDurationThresholds[1])"
        }
        return ""
    }

    var shortMemoConfig: String {
        if let m = memo {
            return m
        }
        if let c = config {
            return "adt: \(c.attenuationDurationThresholds[0])/\(c.attenuationDurationThresholds[1])"
        }
        return ""
    }

    func goDeeper() -> BatchExposureInfo {
        if analysisPasses == numberAnalysisPasses {
            print("Already at \(analysisPasses) passes")
            return self
        }

        do {
            let pass = analysisPasses + 1
            print("starting analysis pass \(pass)")

            let config = CodableExposureConfiguration.getCodableExposureConfiguration(pass: pass)
            let newResults = try ExposureFramework.shared.getExposureInfo(keys: keys,
                                                                          userName: userName,
                                                                          date: Date(),
                                                                          userExplanation: "Analyzing exposures, pass \(pass)", configuration: config)
            print("Got new results")
            var dict: [ExposureKey: CodableExposureInfo] = [:]
            for info in newResults {
                dict[ExposureKey(info: info)] = info
            }
            let result: [CodableExposureInfo] = exposures.map { exposureInfo in
                let key = ExposureKey(info: exposureInfo)

                if let newValue = dict[key] {
                    return CodableExposureInfo(exposureInfo, merging: newValue)
                }
                return exposureInfo
            }

            return BatchExposureInfo(userName: userName,
                                     dateKeysSent: dateKeysSent,
                                     dateProcessed: Date(), keys: keys,
                                     analysisPasses: pass,
                                     config: self.config,
                                     exposures: result)

        } catch {
            print("\(error)")
            return self
        }
    }

    static var testData = BatchExposureInfo(userName: "Bob", dateKeysSent: hoursAgo(2, minutes: 17), dateProcessed: Date(),
                                            keys: [], config: CodableExposureConfiguration.shared,
                                            exposures: CodableExposureInfo.testData)
}

class LocalStore: ObservableObject {
    static let shared = LocalStore()

    let userNameKey = "userName"

    @Published
    var userName: String = ""

    @Published
    var viewShown: String? = nil
    let allExposuresKey = "allExposures"

    @Published
    var allExposures: [BatchExposureInfo] = []
    func deleteAllExposures() {
        print("Deleting all encounters")
        allExposures = []
        if let encoded = try? JSONEncoder().encode(allExposures) {
            UserDefaults.standard.set(encoded, forKey: allExposuresKey)
        }
        objectWillChange.send()
    }

    func appendExposure(_ e: BatchExposureInfo) {
        allExposures.append(e)
        if let encoded = try? JSONEncoder().encode(allExposures) {
            UserDefaults.standard.set(encoded, forKey: allExposuresKey)
        }

        objectWillChange.send()
    }

    func exposuresUpdated(newExposures: [BatchExposureInfo]) {
        if let encoded = try? JSONEncoder().encode(newExposures) {
            UserDefaults.standard.set(encoded, forKey: allExposuresKey)
        }
        DispatchQueue.main.async {
            self.allExposures = newExposures
            self.objectWillChange.send()
        }
    }

    init(userName: String, transmissionRiskLevel: Int, testData: [BatchExposureInfo]) {
        self.userName = userName
        self.transmissionRiskLevel = transmissionRiskLevel
        self.allExposures = testData
    }

    let transmissionRiskLevelKey = "transmissionRiskLevel"
    @Published
    var transmissionRiskLevel: Int = 5

    init() {
        if let data = UserDefaults.standard.string(forKey: userNameKey) {
            self.userName = data
        }
        if let e = UserDefaults.standard.object(forKey: allExposuresKey) as? Data,
            let loadedExposures = try? JSONDecoder().decode([BatchExposureInfo].self, from: e) {
            self.allExposures = loadedExposures
        }

        let t = UserDefaults.standard.integer(forKey: transmissionRiskLevelKey)

        transmissionRiskLevel = t == 0 ? 5 : t - 1
    }

    var shareExposuresURL: URL?

    func exportExposuresToURL() {
        shareExposuresURL = nil
        guard let encoded = try? JSONEncoder().encode(allExposures) else { return }

        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first

        guard let path = documents?.appendingPathComponent("exposures.json") else {
            return
        }

        do {
            print(path)
            try encoded.write(to: path, options: .atomicWrite)
            shareExposuresURL = path
        } catch {
            print(error.localizedDescription)
            return
        }
    }

    func goDeeper() {
        goDeeperQueue.async {
            self.exposuresUpdated(newExposures: self.allExposures.map { info in info.goDeeper() })
        }
    }

    func save() {
        UserDefaults.standard.set(transmissionRiskLevel, forKey: transmissionRiskLevelKey)
        UserDefaults.standard.set(userName, forKey: userNameKey)
        print("User default saved")
    }
}
