//
//  LocalStores.swift
//  GAEN_Explorer
//
//  Created by Bill on 5/24/20.
//

import ExposureNotification
import Foundation

struct PackagedKeys: Codable {
    var userName: String
    var date: Date
    var keys: [CodableDiagnosisKey]
    static let testData = PackagedKeys(userName: "Bob", date: hoursAgo(26, minutes: 17), keys: [])
}

private let goDeeperQueue = DispatchQueue(label: "com.ninjamonkeycoders.gaen.goDeeper", attributes: .concurrent)

struct EncountersWithUser: Codable {
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
    let transmissionRiskLevel: ENRiskLevel
    var keys: [CodableDiagnosisKey]
    var keysChecked: Int {
        keys.count
    }

    init(packedKeys: PackagedKeys, transmissionRiskLevel: ENRiskLevel) {
        self.userName = packedKeys.userName
        self.dateKeysSent = packedKeys.date
        self.dateProcessed = Date()
        self.keys = packedKeys.keys
        self.transmissionRiskLevel = transmissionRiskLevel
        for i in 0 ..< keys.count {
            keys[i].setTransmissionRiskLevel(transmissionRiskLevel: transmissionRiskLevel)
        }
    }

    var analysisPasses = 0

    var exposures: [CodableExposureInfo] = []

    mutating func merge(newAnalysis: [CodableExposureInfo]) {
        var dict: [ExposureKey: CodableExposureInfo] = [:]
        for info in newAnalysis {
            dict[ExposureKey(info: info)] = info
        }
        for i in 0 ..< exposures.count {
            let key = ExposureKey(info: exposures[i])
            if let newValue = dict[key] {
                exposures[i].merge(newValue)
            }
        }
    }

    static var testData = EncountersWithUser(packedKeys: PackagedKeys.testData, transmissionRiskLevel: 0)
}

class LocalStore: ObservableObject {
    static let shared = LocalStore()

    static let userNameKey = "userName"
    static let allExposuresKey = "allExposures"
    static let positionsKey = "positions"

    @Published
    var userName: String = ""

    @Published
    var viewShown: String? = nil

    var positions: [String: Int] = [:]

    func analyze() {
        print("analyze \(allExposures.count)")
        let pass = allExposures.map(\.analysisPasses).min()!

        if allExposures.count == 0 {
            print("Nothing to do")
            return
        }
        if pass + 1 > numberAnalysisPasses {
            print("alread completed pass \(numberAnalysisPasses)")
            return
        }
        viewShown = "exposures"

        goDeeperQueue.async {
            self.analyzeOffMainThread(pass)
        }
    }

    func analyzeOffMainThread(_ pass: Int) {
        print("analyzeOffMainThread, pass \(pass) over \(allExposures.count) users")

        let allKeys = allExposures.filter { $0.analysisPasses == pass }.flatMap { $0.keys }
        print("Have \(allKeys.count) keys")
        let exposures = try! ExposureFramework.shared.getExposureInfo(keys: allKeys,
                                                                      userExplanation: "Analyzing \(allKeys.count), pass # \(pass + 1)",
                                                                      configuration: CodableExposureConfiguration.getCodableExposureConfiguration(pass: pass + 1))
        print("Got \(exposures.count) exposures")
        DispatchQueue.main.async {
            self.incorporateResults(exposures, pass: pass)
        }
    }

    func incorporateResults(_ exposures: [CodableExposureInfo], pass: Int) {
        print("incorporateResults")
        viewShown = "exposures"
        for i in 0 ..< allExposures.count {
            if allExposures[i].analysisPasses == pass {
                print("Updating exposures for \(allExposures[i].userName)")
                allExposures[i].analysisPasses += 1
                if pass == 0 {
                    allExposures[i].exposures = exposures.filter { $0.transmissionRiskLevel == allExposures[i].transmissionRiskLevel }
                } else {
                    allExposures[i].merge(newAnalysis: exposures.filter { $0.transmissionRiskLevel == allExposures[i].transmissionRiskLevel })
                }
            }
        }
        if let encoded = try? JSONEncoder().encode(allExposures) {
            UserDefaults.standard.set(encoded, forKey: Self.allExposuresKey)
        }
    }

    @Published
    var allExposures: [EncountersWithUser] = []
    func deleteAllExposures() {
        print("Deleting all encounters")
        allExposures = []
        positions = [:]
        if let encoded = try? JSONEncoder().encode(allExposures) {
            UserDefaults.standard.set(encoded, forKey: Self.allExposuresKey)
        }
        if let encoded = try? JSONEncoder().encode(positions) {
            UserDefaults.standard.set(encoded, forKey: Self.positionsKey)
        }
        objectWillChange.send()
    }

    func addKeysFromUser(_ e: PackagedKeys) {
        if let i = positions[e.userName] {
            let extractedExpr: EncountersWithUser = EncountersWithUser(packedKeys: e, transmissionRiskLevel: ENRiskLevel(i))
            DispatchQueue.main.async {
                LocalStore.shared.viewShown = "exposures"
                self.allExposures[i] = extractedExpr
                if let encoded = try? JSONEncoder().encode(self.allExposures) {
                    UserDefaults.standard.set(encoded, forKey: Self.allExposuresKey)
                }
            }
        } else {
            let lastIndex = allExposures.count
            let extractedExpr: EncountersWithUser = EncountersWithUser(packedKeys: e, transmissionRiskLevel: ENRiskLevel(lastIndex))
            DispatchQueue.main.async {
                LocalStore.shared.viewShown = "exposures"
                self.positions[e.userName] = lastIndex
                print("positions = \(self.positions)")
                self.allExposures.append(extractedExpr)
                if let encoded = try? JSONEncoder().encode(self.allExposures) {
                    UserDefaults.standard.set(encoded, forKey: Self.allExposuresKey)
                }
                if let encoded = try? JSONEncoder().encode(self.positions) {
                    UserDefaults.standard.set(encoded, forKey: Self.positionsKey)
                }
            }
        }

        if let encoded = try? JSONEncoder().encode(allExposures) {
            UserDefaults.standard.set(encoded, forKey: Self.allExposuresKey)
        }
    }

    func exposuresUpdated(newExposures: [EncountersWithUser]) {
        if let encoded = try? JSONEncoder().encode(newExposures) {
            UserDefaults.standard.set(encoded, forKey: Self.allExposuresKey)
        }
        DispatchQueue.main.async {
            self.allExposures = newExposures
            self.objectWillChange.send()
        }
    }

    init(userName: String, testData: [EncountersWithUser]) {
        self.userName = userName
        self.allExposures = testData
    }

    init() {
        if let data = UserDefaults.standard.string(forKey: Self.userNameKey) {
            self.userName = data
        }
        if let e = UserDefaults.standard.object(forKey: Self.allExposuresKey) as? Data,
            let loadedExposures = try? JSONDecoder().decode([EncountersWithUser].self, from: e) {
            self.allExposures = loadedExposures
        }
        if let data = UserDefaults.standard.object(forKey: Self.positionsKey) as? Data,
            let positions = try? JSONDecoder().decode([String: Int].self, from: data) {
            print("Set positons to \(positions)")
            self.positions = positions
        }
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
            // self.exposuresUpdated(newExposures: self.allExposures.map { info in info.goDeeper() })
        }
    }

    func save() {
        UserDefaults.standard.set(userName, forKey: Self.userNameKey)
        print("User default saved")
    }
}
