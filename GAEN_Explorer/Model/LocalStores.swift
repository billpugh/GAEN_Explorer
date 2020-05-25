//
//  LocalStores.swift
//  GAEN_Explorer
//
//  Created by Bill on 5/24/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import Foundation


struct PackagedKeys: Codable {
    var userName: String
    var date: Date
    var keys: [CodableDiagnosisKey]
}

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
    var memo: String?
    var config: CodableExposureConfiguration?
    let exposures: [CodableExposureInfo]
    var memoConfig: String {
        if memo != nil {
            return memo!
        }
        if config != nil {
            return "ADT: \(config!.attenuationDurationThresholds[0])/\(config!.attenuationDurationThresholds[1])"
        }
        return ""
    }

    static var testData = BatchExposureInfo(userName: "Bob", dateKeysSent: Date(timeIntervalSinceNow: -3 * 24 * 60 * 60), dateProcessed: Date(),
                                            config: CodableExposureConfiguration.shared, exposures: CodableExposureInfo.testData)
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
        print("Deleting all exposures")
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

    init(userName: String, transmissionRiskLevel: Int) {
        self.userName = userName
        self.transmissionRiskLevel = transmissionRiskLevel
        self.allExposures = [BatchExposureInfo.testData]
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

    func save() {
        UserDefaults.standard.set(transmissionRiskLevel, forKey: transmissionRiskLevelKey)
        UserDefaults.standard.set(userName, forKey: userNameKey)
        print("User default saved")
    }
}
