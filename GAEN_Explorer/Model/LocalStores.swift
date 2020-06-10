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
    var dateKeysSent: Date
    var keys: [CodableDiagnosisKey]
    static let testData = PackagedKeys(userName: "Bob", dateKeysSent: hoursAgo(26, minutes: 17), keys: [])
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
    var dateAnalyzed: Date
    let transmissionRiskLevel: ENRiskLevel
    var keys: [CodableDiagnosisKey]
    var keysChecked: Int {
        keys.count
    }

    var packagedKeys: PackagedKeys {
        PackagedKeys(userName: userName, dateKeysSent: dateKeysSent, keys: keys)
    }

    func csvFormat(to: String) -> [String] {
        let pair = [to, userName].sorted().joined(separator: "-")
        return exposures.map { exposureInfo in "exposure, \(to), \(pair),  \(exposureInfo.day), \(exposureInfo.meaningfulDuration), \(exposureInfo.durationsCSV), \(exposureInfo.extendedDuration)" }
    }

    static func csvHeader() -> String {
        let thresholdsHeader = multipassThresholds.sorted().map { String($0) }.joined(separator: ", ")
        return "kind, user, what,  when, detail, \(thresholdsHeader), ∞\n"
    }

    init(packedKeys: PackagedKeys, transmissionRiskLevel: ENRiskLevel, exposures: [CodableExposureInfo] = []) {
        self.userName = packedKeys.userName
        self.dateKeysSent = packedKeys.dateKeysSent
        self.dateAnalyzed = Date()
        self.keys = packedKeys.keys
        self.transmissionRiskLevel = transmissionRiskLevel
        self.exposures = exposures
        for i in 0 ..< keys.count {
            keys[i].setTransmissionRiskLevel(transmissionRiskLevel: transmissionRiskLevel)
        }
    }

    mutating func reset() {
        analysisPasses = 0
        exposures = []
    }

    var analysisPasses = 0

    var exposures: [CodableExposureInfo]

    mutating func merge(newAnalysis: [CodableExposureInfo]) {
        var dict: [ExposureKey: CodableExposureInfo] = [:]
        for info in newAnalysis {
            dict[ExposureKey(info: info)] = info
        }
        dateAnalyzed = Date()
        for i in 0 ..< exposures.count {
            let key = ExposureKey(info: exposures[i])
            if let newValue = dict[key] {
                exposures[i].merge(newValue)
            }
        }
    }

    static var testData = EncountersWithUser(packedKeys: PackagedKeys.testData, transmissionRiskLevel: 0, exposures: CodableExposureInfo.testData)
}

// MARK: - LocalStore

class LocalStore: ObservableObject {
    let fullDateFormatter = DateFormatter()
    let dayFormatter = DateFormatter()
    let shortDateFormatter = DateFormatter()
    let timeFormatter = DateFormatter()

    static let shared = LocalStore()

    static let userNameKey = "userName"
    static let allExposuresKey = "allExposures"
    static let positionsKey = "positions"
    static let diaryKey = "diary"

    @Published
    var userName: String = ""

    @Published
    var viewShown: String? = nil

    func saveUserName() {
        UserDefaults.standard.set(userName, forKey: Self.userNameKey)
        print("User default saved")
    }

    // MARK: - Analysis

    @Published
    var positions: [String: Int] = [:]

    @Published
    var allExposures: [EncountersWithUser] = []

    var canResetAnalysis: Bool {
        if allExposures.count == 0 {
            return false
        }
        let pass = allExposures.map(\.analysisPasses).max()!
        return pass > 0
    }

    var canAnalyze: Bool {
        if allExposures.count == 0 {
            return false
        }
        let pass = allExposures.map(\.analysisPasses).min()!
        return pass + 1 <= numberAnalysisPasses
    }

    var canErase: Bool {
        allExposures.count > 0
    }

    func analyze() {
        if !canAnalyze {
            print("No analysis to do")
            return
        }

        let pass = allExposures.map(\.analysisPasses).min()!
        addDiaryEntry(DiaryKind.analysisPerformed, "\(pass + 1)")
        print("Analyzing")
        goDeeperQueue.async {
            self.analyzeOffMainThread(pass)
        }
    }

    func goDeeper() {
        goDeeperQueue.async {
            // self.exposuresUpdated(newExposures: self.allExposures.map { info in info.goDeeper() })
        }
    }

    func analyzeOffMainThread(_ pass: Int) {
        print("analyzeOffMainThread, pass \(pass) over \(allExposures.count) users")

        let allKeys = allExposures.filter { $0.analysisPasses == pass }.flatMap { $0.keys }
        print("Have \(allKeys.count) keys")
        let wasEnabled = ExposureFramework.shared.manager.exposureNotificationEnabled
        if !wasEnabled {
            ExposureFramework.shared.setExposureNotificationEnabled(true)
        }
        let exposures = try! ExposureFramework.shared.getExposureInfo(keys: allKeys,
                                                                      userExplanation: "Analyzing \(allKeys.count), pass # \(pass + 1)",
                                                                      configuration: CodableExposureConfiguration.getCodableExposureConfiguration(pass: pass + 1))
        print("Got \(exposures.count) exposures")
        if !wasEnabled {
            ExposureFramework.shared.setExposureNotificationEnabled(false)
        }
        DispatchQueue.main.async {
            self.incorporateResults(exposures, pass: pass)
        }
    }

    func incorporateResults(_ exposures: [CodableExposureInfo], pass: Int) {
        print("incorporateResults")
        if viewShown != "experiment" {
            viewShown = "exposures"
        }
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

    func eraseAnalysis() {
        print("erasing analysis for \(allExposures.count) people")
        objectWillChange.send()
        for i in 0 ..< allExposures.count {
            allExposures[i].reset()
        }
        if let encoded = try? JSONEncoder().encode(allExposures) {
            UserDefaults.standard.set(encoded, forKey: Self.allExposuresKey)
        }
    }

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

    // MARK: - Experiment

    var fusedData: [FusedData]?
    var timeSpentInActivity: [Activity: Int]?

    @Published
    var diary: [DiaryEntry] = []

    @Published
    var experimentStarted: Date?
    @Published
    var experimentEnded: Date?

    enum ExperimentStatus {
        case none
        case started
        case completed
    }

    var experimentStatus: ExperimentStatus {
        if experimentStarted == nil {
            return .none
        }
        if experimentEnded == nil {
            return .started
        }
        return .completed
    }

    var experimentMessage: String? {
        switch experimentStatus {
        case .none: return nil
        case .started:
            return "Experiment started \(timeFormatter.string(from: experimentStarted!))"
        case .completed:
            return "Experiment ended \(timeFormatter.string(from: experimentEnded!))"
        }
    }

    func addDiaryEntry(_ kind: DiaryKind, _ text: String = "") {
        diary.append(DiaryEntry(Date(), kind, text))
    }

    func startExperiment(_ framework: ExposureFramework) {
        deleteAllExposures()
        diary = []
        fusedData = nil
        timeSpentInActivity = nil
        SensorFusion.shared.startAccel()
        experimentStarted = Date()
        addDiaryEntry(.startExperiment)
        framework.eraseKeys()
        framework.isEnabled = true
    }

    func endScanningForExperiment(_ framework: ExposureFramework) {
        framework.isEnabled = false
        experimentEnded = Date()
        SensorFusion.shared.getSensorData(from: experimentStarted!, to: experimentEnded!) {
            fusedData, timeSpentInActivity in
            self.fusedData = fusedData
            self.timeSpentInActivity = timeSpentInActivity
        }
    }

    func resetExperiment(_ framework: ExposureFramework) {
        framework.isEnabled = true
        viewShown = nil
        experimentEnded = nil
        experimentStarted = nil
    }

    // MARK: - Lifecycle

    init(userName: String, testData: [EncountersWithUser], diary: [DiaryEntry] = []) {
        self.userName = userName
        self.allExposures = testData
        fullDateFormatter.dateFormat = "yyyy/MM/dd HH:mm ZZZ"
        dayFormatter.dateFormat = "MMM d"
        shortDateFormatter.timeStyle = .short
        shortDateFormatter.dateStyle = .short
        shortDateFormatter.doesRelativeDateFormatting = true
        timeFormatter.timeStyle = .short
        self.diary = diary
    }

    init() {
        fullDateFormatter.dateFormat = "yyyy/MM/dd HH:mm ZZZ"
        dayFormatter.dateFormat = "MMM d"
        shortDateFormatter.timeStyle = .short
        shortDateFormatter.dateStyle = .short
        shortDateFormatter.doesRelativeDateFormatting = true
        timeFormatter.timeStyle = .short

        if let data = UserDefaults.standard.string(forKey: Self.userNameKey) {
            self.userName = data
        }
        if let diaryData = UserDefaults.standard.object(forKey: Self.diaryKey) as? Data,
            let loadedDiary = try? JSONDecoder().decode([DiaryEntry].self, from: diaryData) {
            self.diary = loadedDiary
        }
        if let exposureData = UserDefaults.standard.object(forKey: Self.allExposuresKey) as? Data,
            let loadedExposures = try? JSONDecoder().decode([EncountersWithUser].self, from: exposureData),
            let data = UserDefaults.standard.object(forKey: Self.positionsKey) as? Data,
            let positions = try? JSONDecoder().decode([String: Int].self, from: data) {
            if loadedExposures.count == loadedExposures.count {
                self.allExposures = loadedExposures
                self.positions = positions
            } else {
                print("mismatched count \(loadedExposures.count) \(loadedExposures.count)")
            }
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

    // MARK: - Export/import keys

    var shareExposuresURL: URL?

    func getAndPackageKeys(_ result: @escaping (Bool) -> Void) {
        let keys: [PackagedKeys] = allExposures.map { $0.packagedKeys }
        ExposureFramework.shared.getAndPackageKeys(userName: userName, otherKeys: keys, result)
    }

    func importDiagnosisKeys(from url: URL, completionHandler: ((Bool) -> Void)? = nil) {
        print("got url \(url)")
        do {
            let data = try Data(contentsOf: url)
            if let packagedKeys = try? JSONDecoder().decode([PackagedKeys].self, from: data) {
                packagedKeys.forEach {
                    addKeysFromUser($0)
                }
            } else {
                addKeysFromUser(try JSONDecoder().decode(PackagedKeys.self, from: data))
            }
            if LocalStore.shared.viewShown != "experiment" {
                LocalStore.shared.viewShown = "exposures"
            }
            if let encoded = try? JSONEncoder().encode(allExposures) {
                UserDefaults.standard.set(encoded, forKey: Self.allExposuresKey)
            }
            if let encoded = try? JSONEncoder().encode(positions) {
                UserDefaults.standard.set(encoded, forKey: Self.positionsKey)
            }
        } catch {
            print("Unexpected error: \(error)")
            completionHandler?(false)
        }
    }

    func addKeysFromUser(_ e: PackagedKeys) {
        if e.userName == userName {
            print("Got my own keys back, ignoring")
            return
        }
        addDiaryEntry(DiaryKind.keysReceived, e.userName)
        if let i = positions[e.userName] {
            if allExposures[i].dateKeysSent < e.dateKeysSent {
                let extractedExpr: EncountersWithUser = EncountersWithUser(packedKeys: e, transmissionRiskLevel: ENRiskLevel(i))
                allExposures[i] = extractedExpr
                print("Updated \(extractedExpr.keys.count) keys from \(e.userName)")
            } else {
                print("Ignoring older keys from \(e.userName)")
            }
        } else {
            let lastIndex = allExposures.count
            let extractedExpr: EncountersWithUser = EncountersWithUser(packedKeys: e, transmissionRiskLevel: ENRiskLevel(lastIndex))

            positions[e.userName] = lastIndex
            print("positions = \(positions)")
            allExposures.append(extractedExpr)
            print("Have \(extractedExpr.keys.count) keys from \(e.userName)")
        }
    }

    // MARK: - Export exposures

    func csvExport() -> String {
        let exposuresCSV = EncountersWithUser.csvHeader() + allExposures.flatMap { exposure in exposure.csvFormat(to: userName) }.joined(separator: "\n")
        let diaryCSV = diary.map { $0.csv(user: userName) }.joined(separator: "\n")
        guard let timeSpentCSV = timeSpentInActivity?.map({ "time, \(userName), \($0.key), \($0.value), secs " }).joined(separator: "\n") else {
            return exposuresCSV + "\n" + diaryCSV
        }
        return exposuresCSV + "\n" + diaryCSV + "\n" + timeSpentCSV
    }

    func exportExposuresToURL() {
        shareExposuresURL = nil
        let csv = csvExport()
        print(csv)
        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first

        guard let path = documents?.appendingPathComponent("exposures.csv") else {
            return
        }

        do {
            print(path)
            try csv.write(to: path, atomically: true, encoding: .utf8)
            addDiaryEntry(DiaryKind.exposuresShared)
            shareExposuresURL = path
        } catch {
            print(error.localizedDescription)
            return
        }
    }

    func exportRawExposuresToURL() {
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
}
