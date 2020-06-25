//
//  LocalStores.swift
//  GAEN_Explorer
//
//  Created by Bill on 5/24/20.
//

import ExposureNotification
import Foundation
import UIKit

struct PackagedKeys: Codable {
    let userName: String
    let deviceId: Int = LocalStore.shared.deviceId
    let dateKeysSent: Date
    let keys: [CodableDiagnosisKey]
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
    var experiment: ExperimentSummary?
    let transmissionRiskLevel: ENRiskLevel
    var keys: [CodableDiagnosisKey]
    var keysChecked: Int {
        keys.count
    }

    var packagedKeys: PackagedKeys {
        PackagedKeys(userName: userName, dateKeysSent: dateKeysSent, keys: keys)
    }

    func rawAnalysisCSV(_ to: String, _ pair: String, exposureInfo: CodableExposureInfo) -> [String] {
        (1 ... exposureInfo.rawAnalysis.count).map { pass in
            let ra = exposureInfo.rawAnalysis[pass - 1]
            return "rawAnalysis, \(to), \(pair), \(exposureInfo.day), \(pass), \(ra.thresholdsCSV), \(ra.bucketsCSV)"
        }
    }

    func csvFormat(to: String) -> [String] {
        let pair = [to, userName].sorted().joined(separator: "-")
        return exposures.flatMap { exposureInfo in
            ["""
            exposure, \(to), \(pair), \(exposureInfo.day), cumulative,  \(exposureInfo.durationsCSV),
            exposure, \(to), \(pair), \(exposureInfo.day), inBucket,  \(exposureInfo.timeInBucketCSV)
            """] + rawAnalysisCSV(to, pair, exposureInfo: exposureInfo)
        }
    }

    static func csvHeader(_ thresholds: [Int]) -> String {
        let thresholdsHeader = thresholds.map { $0 == maxAttenuation ? "∞" : String($0) }.joined(separator: ", ")
        return "kind, user, what, when, detail, \(thresholdsHeader)\n"
    }

    init(packedKeys: PackagedKeys, transmissionRiskLevel: ENRiskLevel, experiment: ExperimentSummary? = nil, exposures: [CodableExposureInfo] = []) {
        self.userName = packedKeys.userName
        self.dateKeysSent = packedKeys.dateKeysSent
        self.dateAnalyzed = Date()
        self.keys = packedKeys.keys
        self.transmissionRiskLevel = transmissionRiskLevel
        self.experiment = experiment
        self.exposures = exposures
        for i in 0 ..< keys.count {
            keys[i].setTransmissionRiskLevel(transmissionRiskLevel: transmissionRiskLevel)
        }
    }

    mutating func reset() {
        analysisPasses = 0
        noMatches = false
        exposures = []
    }

    var analysisPasses = 0

    var noMatches: Bool = false

    var exposures: [CodableExposureInfo]

    static func merge(existing: inout [CodableExposureInfo], newAnalysis: [CodableExposureInfo]) {
        var dict: [ExposureKey: CodableExposureInfo] = [:]
        for info in newAnalysis {
            dict[ExposureKey(info: info)] = info
        }

        for i in 0 ..< existing.count {
            let key = ExposureKey(info: existing[i])
            if let newValue = dict[key] {
                existing[i].merge(newValue)
            }
        }
    }

    mutating func merge(newAnalysis: [CodableExposureInfo]) {
        dateAnalyzed = Date()
        EncountersWithUser.merge(existing: &exposures, newAnalysis: newAnalysis)
    }

    mutating func reanalyze() {
        for i in 0 ..< exposures.count {
            exposures[i].reanalyze()
        }
    }

    static var testData = EncountersWithUser(packedKeys: PackagedKeys.testData, transmissionRiskLevel: 0, exposures: CodableExposureInfo.testData)
}

struct ExperimentSummary: Codable {
    let started: Date
    let ended: Date
    let description: String
}

func makeDateFormatter(tweaks: (DateFormatter) -> DateFormatter) -> DateFormatter {
    tweaks(DateFormatter())
}

let fullDateFormatter: DateFormatter = makeDateFormatter {
    $0.dateFormat = "yyyy/MM/dd HH:mm ZZZ"
    return $0
}

let dayFormatter: DateFormatter = makeDateFormatter {
    $0.dateFormat = "MMM d"
    return $0
}

let shortDateFormatter: DateFormatter = makeDateFormatter {
    $0.timeStyle = .short
    $0.dateStyle = .short
    return $0
}

let relativeDateFormatter: DateFormatter = makeDateFormatter {
    $0.timeStyle = .short
    $0.dateStyle = .short
    $0.doesRelativeDateFormatting = true
    return $0
}

let timeFormatter: DateFormatter = makeDateFormatter {
    $0.timeStyle = .short
    return $0
}

extension String.StringInterpolation {
    mutating func appendInterpolation(day: Date) {
        appendLiteral(dayFormatter.string(from: day))
    }

    mutating func appendInterpolation(fullDate: Date) {
        appendLiteral(fullDateFormatter.string(from: fullDate))
    }

    mutating func appendInterpolation(date: Date) {
        appendLiteral(shortDateFormatter.string(from: date))
    }

    mutating func appendInterpolation(relativeDate: Date) {
        appendLiteral(relativeDateFormatter.string(from: relativeDate))
    }

    mutating func appendInterpolation(time: Date) {
        appendLiteral(timeFormatter.string(from: time))
    }
}

// MARK: - LocalStore

struct AnalysisParameters {
    let doMaxAnalysis: Bool
    let trueDuration: TimeInterval?
    let wasEnabled: Bool
    init(doMaxAnalysis: Bool = false,
         trueDuration: TimeInterval? = nil,
         wasEnabled: Bool = ExposureFramework.shared.manager.exposureNotificationEnabled) {
        self.doMaxAnalysis = doMaxAnalysis
        self.trueDuration = trueDuration
        self.wasEnabled = wasEnabled
    }
}

class LocalStore: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = LocalStore()

    static let userNameKey = "userName"
    static let deviceIdKey = "deviceId"
    static let allExposuresKey = "allExposures"
    static let positionsKey = "positions"
    static let diaryKey = "diary"

    @Published
    var userName: String = "" {
        didSet {
            UserDefaults.standard.set(userName, forKey: Self.userNameKey)
        }
    }

    @Published
    var deviceId: Int = 0 {
        didSet {
            UserDefaults.standard.set(deviceId, forKey: Self.deviceIdKey)
        }
    }

    @Published
    var viewShown: String? = nil

    func changeView(to: String?) {
        if viewShown != to {
            viewShown = to
        }
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

    var analysisPassedCompleted: Int {
        if allExposures.count == 0 {
            return 0
        }
        return allExposures.map(\.analysisPasses).min()!
    }

    var canAnalyze: Bool {
        analysisPassedCompleted < numberAnalysisPasses
    }

    var haveKeysFromOthers: Bool {
        allExposures.count > 0
    }

    var analysisInProgress = false

    var showEncountersMsg: String {
        if allExposures.count == 0 {
            return "No keys or analysis yet"
        }
        if analysisPassedCompleted == 0 {
            if allExposures.count == 1 {
                return "Show key from \(allExposures[0].userName)"
            }
            return "Show keys from \(allExposures.count) devices"
        }
        if allExposures.count == 1 {
            return "Show encounter with \(allExposures[0].userName)"
        }
        return "Show encounters with \(allExposures.count) devices"
    }

    func analyze(parameters: AnalysisParameters = AnalysisParameters(), whenDone: @escaping () -> Void) {
        if !canAnalyze {
            print("No analysis to do")
            whenDone()
            return
        }
        if analysisInProgress {
            print("Analysis in progress")
            whenDone()
            return
        }

        let pass = allExposures.map(\.analysisPasses).min()!
        if !parameters.doMaxAnalysis {
            addDiaryEntry(DiaryKind.analysisPerformed, "\(pass + 1)")
        }
        print("Analyzing")
        goDeeperQueue.async {
            self.analyzeOffMainThread(pass, parameters, whenDone: whenDone)
        }
    }

    func analyzeExperiment(_ parameters: AnalysisParameters = AnalysisParameters()) {
        goDeeperQueue.async {
            self.analyzeExperimentOffMainThread(parameters)
        }
    }

    func analyzeExperimentOffMainThread(_ parameters: AnalysisParameters) {
        print("AnalyzeExperiment, over \(allExposures.count) users")
        assert(!Thread.current.isMainThread)
        let allKeys = allExposures.filter { $0.analysisPasses == 0 && !$0.noMatches }.flatMap { $0.keys }
        print("AnalyzeExperiment, over \(allExposures.count) users, \(allKeys.count) keys")
        var combinedExposures: [[CodableExposureInfo]] = Array(repeating: [], count: allExposures.count)
        print("Turning on exposure notifications")
        ExposureFramework.shared.setExposureNotificationEnabledSync(true)
        print("exposure notifications turned on: \(ExposureFramework.shared.isEnabled)")
        for pass in 1 ... numberAnalysisPasses {
            print("Performing analysis pass \(pass)")
            let config = CodableExposureConfiguration.getCodableExposureConfiguration(pass: pass)
            let exposures = try! ExposureFramework.shared.getExposureInfoSync(keys: allKeys, userExplanation: "Analyzing \(allKeys.count) keys, pass # \(pass)", parameters, configuration: config)

            for i in 0 ..< allExposures.count {
                let exposuresForThisUser = exposures.filter { $0.transmissionRiskLevel == allExposures[i].transmissionRiskLevel }
                print("Got \(exposuresForThisUser.count) exposures for \(allExposures[i].userName)")
                if pass == 1 {
                    combinedExposures[i] = exposuresForThisUser
                } else {
                    EncountersWithUser.merge(existing: &combinedExposures[i], newAnalysis: exposuresForThisUser)
                }
            }
        } // analysis pass
        print("All analysis passes complete")
        for i in 0 ..< combinedExposures.count {
            print("Reanalyzing \(combinedExposures[i].count) exposures for \(allExposures[i].userName)")
            for j in 0 ..< combinedExposures[i].count {
                combinedExposures[i][j].reanalyze()
            }
        }

        DispatchQueue.main.async {
            print("Adding experiments results to local store")
            for i in 0 ..< self.allExposures.count {
                if !combinedExposures[i].isEmpty {
                    print("Updates exposures for \(self.allExposures[i].userName)")
                    self.allExposures[i].analysisPasses = numberAnalysisPasses
                    self.allExposures[i].exposures = combinedExposures[i]
                }
            }
            if let encoded = try? JSONEncoder().encode(self.allExposures) {
                UserDefaults.standard.set(encoded, forKey: Self.allExposuresKey)
            }
        }
    }

    func analyzeOffMainThread(_ pass: Int, _ parameters: AnalysisParameters, whenDone: @escaping () -> Void) {
        print("analyzeOffMainThread, pass \(pass) over \(allExposures.count) users")
        assert(!Thread.current.isMainThread)
        let allKeys = allExposures.filter { $0.analysisPasses == pass && !$0.noMatches }.flatMap { $0.keys }
        print("Have \(allKeys.count) keys")

        ExposureFramework.shared.setExposureNotificationEnabledSync(true)

        let exposures = try! ExposureFramework.shared.getExposureInfoSync(keys: allKeys,
                                                                          userExplanation: "Analyzing \(allKeys.count), pass # \(pass + 1)",
                                                                          parameters,
                                                                          configuration: CodableExposureConfiguration.getCodableExposureConfiguration(pass: pass + 1))

        print("Got \(exposures.count) exposures")
        if exposures.isEmpty {
            print("Didn't get any exposures")
            for i in 0 ..< allExposures.count {
                if allExposures[i].analysisPasses == pass {
                    allExposures[i].noMatches = true
                }
            }
            if !parameters.wasEnabled {
                ExposureFramework.shared.setExposureNotificationEnabledSync(false)
            }
            return
        }
        print("Got \(exposures.count) exposures")
        if !parameters.wasEnabled && !parameters.doMaxAnalysis {
            ExposureFramework.shared.setExposureNotificationEnabled(false) { _ in }
        }
        DispatchQueue.main.async {
            self.incorporateResults(exposures, pass: pass, parameters, whenDone: whenDone)
        }
    }

    func incorporateResults(_ exposures: [CodableExposureInfo], pass: Int, _ parameters: AnalysisParameters, whenDone: @escaping () -> Void) {
        print("incorporateResults")
        assert(Thread.current.isMainThread)
        if viewShown != "experiment" {
            changeView(to: "exposures")
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

        if parameters.doMaxAnalysis, canAnalyze {
            let nextPass = pass + 1
            addDiaryEntry(DiaryKind.analysisPerformed, "\(nextPass + 1)")
            print("Analyzing")
            goDeeperQueue.async {
                self.analyzeOffMainThread(nextPass, parameters, whenDone: whenDone)
            }
            return
        }
        analysisInProgress = false
        if !parameters.wasEnabled {
            ExposureFramework.shared.setExposureNotificationEnabled(false) { _ in }
        }
        print("Performing reanalysis")
        for i in 0 ..< allExposures.count {
            allExposures[i].reanalyze()
        }
        if let encoded = try? JSONEncoder().encode(allExposures) {
            UserDefaults.standard.set(encoded, forKey: Self.allExposuresKey)
        }
        whenDone()
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

    @Published
    var experimentStart: Date?

    @Published
    var experimentEnd: Date?

    @Published
    var experimentDescription: String = ""

    @Published
    var experimentDurationMinutes: Int = 29

    enum ExperimentStatus {
        case none
        case launching
        case running
        case analyzing
        case analyzed
    }

    var experimentStatus: ExperimentStatus = .none

    var experimentMessage: String? {
        switch experimentStatus {
        case .none: return nil
        case .running:
            return "Experiment started \(time: experimentStart!)"
        case .analyzing:
            return "Scanning ended at \(time: experimentEnd!))"
        case .launching:
            return "Experiment starts at \(time: experimentStart!)"
        case .analyzed:
            return "Experiment completed at \(time: experimentEnd!))"
        }
    }

    func scheduleAt(fire: Date?, block: @escaping (Timer) -> Void) {
        print("Scheduled action for \(time: fire!)")
        let timer = Timer(fire: fire!, interval: 0, repeats: false, block: block)
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
    }

    func launchExperiment(_ framework: ExposureFramework) {
        assert(experimentStatus == .none)
        print("Launching experiment")
        experimentStatus = .launching
        scheduleAt(fire: experimentStart) { _ in
            self.startExperiment(framework)
        }
    }

    func startExperiment(_ framework: ExposureFramework) {
        switch experimentStatus {
        case .none, .analyzed:
            print("Starting experiment manually")
            experimentStart = Date()
        case .launching:
            print("Experiment moving from launched to started")
        case .running, .analyzing:
            assert(false)
        }
        eraseAnalysis()
        diary = []
        experimentStatus = .running
        significantActivites = nil
        timeSpentInActivity = nil
        SensorFusion.shared.startAccel()

        addDiaryEntry(.startExperiment)
        framework.isEnabled = true
        if let ends = experimentEnd {
            scheduleAt(fire: ends) { _ in
                self.endScanningForExperiment(framework)
            }
        }
    }

    var experimentSummary: ExperimentSummary? {
        if let started = experimentStart,
            let ended = experimentEnd {
            return ExperimentSummary(started: started, ended: ended, description: experimentDescription)
        }
        return nil
    }

    func endScanningForExperiment(_ framework: ExposureFramework) {
        assert(experimentStatus == .running)
        // framework.isEnabled = false
        experimentStatus = .analyzing
        addDiaryEntry(.endExperiment)
        if experimentEnd == nil {
            experimentEnd = Date()
        }
        SensorFusion.shared.getSensorData(from: experimentStart!, to: experimentEnd!) {
            significantActivities, timeSpentInActivity in
            self.significantActivites = significantActivities
            self.timeSpentInActivity = timeSpentInActivity
            if let sa = significantActivities {
                self.diary.append(contentsOf: sa.map { DiaryEntry(significantActivity: $0) })
                self.diary.sort(by: { $0.at < $1.at })
            }
        }
        if haveKeysFromOthers {
            let parameters = AnalysisParameters(doMaxAnalysis: true,
                                                trueDuration: experimentEnd!.timeIntervalSince(experimentStart!),
                                                wasEnabled: true)
            LocalStore.shared.analyzeExperiment(parameters)
            experimentStatus = .analyzed
            saveExperimentalResults(framework)
        }
    }

    func saveExperimentalResults(_: ExposureFramework) {
        print("save experimental results")
    }

    func resetExperiment(_: ExposureFramework) {
        viewShown = nil
        experimentEnd = nil
        experimentStart = nil
        experimentStatus = .none
        experimentDescription = ""
        diary = []
        significantActivites = nil
        timeSpentInActivity = nil
    }

    // MARK: Diary

    var significantActivites: [SignificantActivity]?
    var timeSpentInActivity: [Activity: Int]?

    @Published
    var diary: [DiaryEntry] = []

    func addDiaryEntry(_ kind: DiaryKind, _ text: String = "") {
        diary.append(DiaryEntry(Date(), kind, text))
    }

    func addMemoToDiary(_ text: String) {
        diary.append(DiaryEntry(Date(), .memo, "\"\(text)\""))
    }

    // MARK: Notifications

    func registerLocalNotification() {
        print("registerLocalNotification")
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getNotificationSettings { settings in
            print(settings)
        }
        notificationCenter.delegate = self
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]

        notificationCenter.requestAuthorization(options: options) {
            didAllow, _ in
            if !didAllow {
                print("User has declined notifications")
            } else {
                print("User allowed notifications")
            }
        }

        let acceptAction = UNNotificationAction(identifier: "END_ACTION",
                                                title: "End experiment",
                                                options: UNNotificationActionOptions(rawValue: 0))
        // Define the notification type
        let endExperimentCategory =
            UNNotificationCategory(identifier: "GAEN_END_EXPERIMENT",
                                   actions: [acceptAction],
                                   intentIdentifiers: [])
        // Register the notification type.
        notificationCenter.setNotificationCategories([endExperimentCategory])
        print("Registered GAEN_END_EXPERIMENT notification")
    }

    func userNotificationCenter(_: UNUserNotificationCenter,
                                didReceive _: UNNotificationResponse,
                                withCompletionHandler completionHandler:
                                @escaping () -> Void) {
        print("Got local notification, ending scanning")
        endScanningForExperiment(ExposureFramework.shared)
        // Always call the completion handler when done.
        completionHandler()
    }

    // MARK: - Lifecycle

    init(userName: String, testData: [EncountersWithUser], diary: [DiaryEntry] = []) {
        self.userName = userName
        self.allExposures = testData

        self.diary = diary
    }

    override init() {
        if let data = UserDefaults.standard.string(forKey: Self.userNameKey) {
            self.userName = data
        }
        self.deviceId = UserDefaults.standard.integer(forKey: Self.deviceIdKey)

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
        super.init()
        registerLocalNotification()
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

    func getAndPackageKeys(_ result: @escaping (URL?) -> Void) {
        let keys: [PackagedKeys] = allExposures.map { $0.packagedKeys }
        ExposureFramework.shared.exportAllKeys(userName: userName, otherKeys: keys, result)
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
                LocalStore.shared.changeView(to: "exposures")
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
                let extractedExpr: EncountersWithUser = EncountersWithUser(packedKeys: e, transmissionRiskLevel: ENRiskLevel(i), experiment: experimentSummary)
                allExposures[i] = extractedExpr
                print("Updated \(extractedExpr.keys.count) keys from \(e.userName)")
            } else {
                print("Ignoring older keys from \(e.userName)")
            }
        } else {
            let lastIndex = allExposures.count
            let extractedExpr: EncountersWithUser = EncountersWithUser(packedKeys: e, transmissionRiskLevel: ENRiskLevel(lastIndex), experiment: experimentSummary)

            positions[e.userName] = lastIndex
            print("positions = \(positions)")
            allExposures.append(extractedExpr)
            print("Have \(extractedExpr.keys.count) keys from \(e.userName)")
        }
    }

    // MARK: - Export exposures

    func csvSafe(_ txt: String) -> String {
        if txt.isEmpty {
            return ""
        }
        return "\"\(txt)\""
    }

    func csvExport() -> String {
        var thresholds: [Int] = Set(multipassThresholds).sorted() + [maxAttenuation]
        if let sample = allExposures.first?.exposures.first {
            thresholds = sample.sortedThresholds
        }

        var result = EncountersWithUser.csvHeader(thresholds)
            + allExposures.flatMap { exposure in exposure.csvFormat(to: userName) }.joined(separator: "\n") + "\n"

        result += "device, \(userName), export, \(fullDate: Date()), \(csvSafe(deviceModelName())), handicap:, \(phoneAttenuationHandicap))\n"
        if let start = experimentStart,
            let ended = experimentEnd {
            result += """
            experiment, \(userName), description, \(fullDate: start), \(csvSafe(experimentDescription))
            experiment, \(userName), duration, \(fullDate: ended), \(Int(ended.timeIntervalSince(start) / 60))\n
            """
        }

        let diaryCSV = diary.map { $0.csv(user: userName) }.joined(separator: "\n")
        if !diaryCSV.isEmpty {
            result = result + diaryCSV + "\n"
        }

        if let timeSpentCSV = timeSpentInActivity?.map({ "time, \(userName), \($0.key), \($0.value), secs " }).joined(separator: "\n") {
            result = result + timeSpentCSV + "\n"
        }
        return result
    }

    func exportExposuresToURL() {
        shareExposuresURL = nil
        let csv = csvExport()
        print(csv)
        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first

        guard let path = documents?.appendingPathComponent("\(userName).csv") else {
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
