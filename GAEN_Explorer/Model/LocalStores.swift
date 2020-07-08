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

private let analysisQueue = DispatchQueue(label: "com.ninjamonkeycoders.gaen.analysis", attributes: .concurrent)

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
    let transmissionRiskLevel: ENRiskLevel
    var keys: [CodableDiagnosisKey]
    var keysChecked: Int {
        keys.count
    }

    var packagedKeys: PackagedKeys {
        PackagedKeys(userName: userName, dateKeysSent: dateKeysSent, keys: keys)
    }

    func rawAnalysisCSV(_ owner: String, _ pair: String, exposureInfo: CodableExposureInfo) -> [String] {
        (1 ... exposureInfo.rawAnalysis.count).map { pass in
            let ra = exposureInfo.rawAnalysis[pass - 1]
            return "rawAnalysis, \(owner), \(userName),  \(pair), \(exposureInfo.day), \(pass),  \(ra.thresholdsCSV),  \(ra.bucketsCSV)"
        }
    }

    func teksCSV(owner: String, pair _: String) -> [String] {
        keys.map {
            "tek, \(owner), \(userName), \($0.rollingStartNumber),  \($0.rollingPeriod), \(exposures.isEmpty ? "unseen" : ""), \($0.keyString)"
        }
    }

    func csvFormat(owner: String) -> [String] {
        let pair = [owner, userName].sorted().joined(separator: "=")
        return exposures.flatMap { exposureInfo in
            ["""
            exposure, \(owner), \(userName),  \(pair), \(exposureInfo.day), cumulative,  \(exposureInfo.durationsCSV)
            exposure, \(owner), \(userName),  \(pair), \(exposureInfo.day), inBucket,  \(exposureInfo.timeInBucketCSV)
            """]
                + rawAnalysisCSV(owner, pair, exposureInfo: exposureInfo)

        } + teksCSV(owner: owner, pair: pair)
    }

    static func csvHeader(_ thresholds: [Int]) -> String {
        let thresholdsHeader = thresholds.map { String($0) }.joined(separator: ", ")
        return "kind, owner, from, pair, when, detail, \(thresholdsHeader)\n"
    }

    init(packedKeys: PackagedKeys, transmissionRiskLevel: ENRiskLevel, experiment: ExperimentSummary? = nil, exposures: [CodableExposureInfo] = []) {
        self.userName = packedKeys.userName
        self.dateKeysSent = packedKeys.dateKeysSent
        self.dateAnalyzed = Date()
        self.analyzed = !exposures.isEmpty
        self.keys = packedKeys.keys
        self.transmissionRiskLevel = transmissionRiskLevel
        self.experiment = experiment
        self.exposures = exposures
        for i in 0 ..< keys.count {
            keys[i].setTransmissionRiskLevel(transmissionRiskLevel: transmissionRiskLevel)
        }
    }

    mutating func reset() {
        analyzed = false
        exposures = []
    }

    // MARK: data from analysis and experiments

    var dateAnalyzed: Date

    var experiment: ExperimentSummary?

    var analyzed = false

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
        let analyzed = allExposures.filter { $0.analyzed }.count
        return analyzed > 0
    }

    var canAnalyze: Bool {
        let notAnalyzed = allExposures.filter { !$0.analyzed }.count
        return notAnalyzed > 0
    }

    var haveKeysFromOthers: Bool {
        allExposures.count > 0
    }

    var analysisInProgress = false

    var showEncountersMsg: String {
        if allExposures.count == 0 {
            return "No keys or analysis yet"
        }
        let analyzed = allExposures.filter { $0.analyzed }.count
        let exposures = allExposures.filter { !$0.exposures.isEmpty }.count
        let notAnalyzed = allExposures.count - analyzed
        var msg: [String] = []
        if exposures > 0 {
            msg.append("\(exposures) exposures")
        }
        if analyzed - exposures > 0 {
            msg.append("\(analyzed - exposures) not matched")
        }
        if notAnalyzed > 0 {
            msg.append("\(notAnalyzed) keys")
        }
        return msg.joined(separator: ", ")
    }

    func analyzeExperiment(_ parameters: AnalysisParameters = AnalysisParameters()) {
        analysisQueue.async {
            self.analyzeExperimentOffMainThread(parameters)
        }
    }

    func updateAllExposures(_ combinedExposures: [[CodableExposureInfo]]) {
        print("Adding experiments results to local store")
        for i in 0 ..< allExposures.count {
            if allExposures[i].analyzed {
                print("Already analyzed exposures for \(allExposures[i].userName)")
                continue
            }
            allExposures[i].analyzed = true
            if !combinedExposures[i].isEmpty {
                print("Updates exposures for \(allExposures[i].userName)")
                allExposures[i].exposures = combinedExposures[i]
            }
        }
        if let encoded = try? JSONEncoder().encode(allExposures) {
            UserDefaults.standard.set(encoded, forKey: Self.allExposuresKey)
        }
    }

    fileprivate func combinePasses(_: inout [[CodableExposureInfo]]) {}

    func analyzeExperimentOffMainThread(_ parameters: AnalysisParameters) {
        assert(!Thread.current.isMainThread)
        assert(ExposureFramework.shared.manager.exposureNotificationEnabled)
        let allKeys = allExposures.filter { !$0.analyzed }.flatMap { $0.keys }
        print("AnalyzeExperiment at \(time: Date()) over \(allExposures.count) users, \(allKeys.count) keys")
        var combinedExposures: [[CodableExposureInfo]] = Array(repeating: [], count: allExposures.count)

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
        }
        // reanalysis pass
        print("All analysis passes complete, performing reanalysis")
        for i in 0 ..< combinedExposures.count {
            print("Reanalyzing \(combinedExposures[i].count) exposures for \(allExposures[i].userName)")
            for j in 0 ..< combinedExposures[i].count {
                combinedExposures[i][j].reanalyze()
            }
        }
        DispatchQueue.main.async {
            self.updateAllExposures(combinedExposures)
        }
    }

    func eraseAnalysis() {
        print("erasing analysis for \(allExposures.count) people")
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

    var experimentDescription: String = ""

    @Published
    var experimentDurationMinutes: Int = 29

    enum ExperimentStatus: String {
        case none
        case launching
        case running
        case analyzing
        case analyzed
    }

    let experimentQueue = DispatchQueue(label: "Experiment queue")

    var measureMotions = false

    @Published
    var observedExperimentStatus: ExperimentStatus = .none

    var experimentStatus: ExperimentStatus = .none {
        didSet {
            print("Changing experiment status to \(experimentStatus)")

            DispatchQueue.main.async {
                print("Changing observed experiment status to \(self.experimentStatus)")
                self.observedExperimentStatus = self.experimentStatus
            }
        }
    }

    var experimentMessage: String? {
        switch observedExperimentStatus {
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

    func scheduleAt(fire: Date, function: String = #function, block: @escaping () -> Void) -> DispatchWorkItem {
        print("Scheduled action for \(time: fire) from \(function) \(Thread.current.isMainThread ? " on main thread" : "")")
        let work = DispatchWorkItem(block: block)
        experimentQueue.asyncAfter(deadline: .now() + fire.timeIntervalSince(Date()), execute: work)
        return work
    }

    func trackThread(funcname: String = #function) {
        let thread = Thread.current
        if thread.isMainThread {
            print("main Thread calling \(funcname) at \(time: Date())")
        } else {
            print("nonmain Thread calling \(funcname) at \(time: Date())")
        }
        Thread.callStackSymbols.forEach { print($0) }
    }

    var startExperimentTimer: DispatchWorkItem?
    var endExperimentTimer: DispatchWorkItem?
    func launchExperiment(_ framework: ExposureFramework) {
        trackThread()
        if measureMotions {
            SensorFusion.shared.startAccel()
        }
        print("Launching experiment from \(experimentStatus)")
        assert(experimentStatus == .none)
        experimentStatus = .launching
        if let experimentEnd = experimentEnd {
            scheduleExperimentEndedNotification(at: experimentEnd)
        }
        analysisQueue.async {
            self.startExperimentTimer = self.scheduleAt(fire: self.experimentStart!) {
                self.startExperiment(framework)
            }
        }
    }

    func startExperiment(_ framework: ExposureFramework) {
        trackThread()
        switch experimentStatus {
        case .none, .analyzed:
            print("Starting experiment manually")
            experimentStart = Date()
        case .launching:
            print("Experiment moving from launched to started")
        case .running, .analyzing:
            assert(false)
        }

        startExperimentTimer?.cancel()
        startExperimentTimer = nil
        diary = []
        experimentStatus = .running
        significantActivites = nil
        timeSpentInActivity = nil
        if measureMotions {
            SensorFusion.shared.startAccel()
        }

        addDiaryEntry(.startExperiment)
        framework.isEnabled = true
        if let ends = experimentEnd {
            analysisQueue.async {
                self.endExperimentTimer = self.scheduleAt(fire: ends) {
                    self.endScanningForExperiment(framework)
                }
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
        trackThread()

        if experimentStatus == .analyzing || experimentStatus == .analyzed {
            print("Experiment already analyzed")
            return
        }
        assert(experimentStatus == .running)
        endExperimentTimer?.cancel()
        endExperimentTimer = nil
        experimentStatus = .analyzing
        addDiaryEntry(.endExperiment)
        if experimentEnd == nil {
            experimentEnd = Date()
        }
        notificationCenter.removeAllPendingNotificationRequests()
        if haveKeysFromOthers {
            let duration = experimentEnd!.timeIntervalSince(experimentStart!)
            print("Experiment duration: \(duration)")
            let parameters = AnalysisParameters(doMaxAnalysis: true,
                                                trueDuration: duration,
                                                wasEnabled: true)
            LocalStore.shared.analyzeExperiment(parameters) // done asynchronously
            experimentStatus = .analyzed
            saveExperimentalResults(framework) // currently no-op
        }
        if measureMotions {
            SensorFusion.shared.getSensorData(from: experimentStart!, to: experimentEnd!) {
                significantActivities, timeSpentInActivity in
                self.significantActivites = significantActivities
                self.timeSpentInActivity = timeSpentInActivity
                if let sa = significantActivities {
                    self.diary.append(contentsOf: sa.map { DiaryEntry(significantActivity: $0) })
                    self.diary.sort(by: { $0.at < $1.at })
                }
            }
        }
    }

    func saveExperimentalResults(_: ExposureFramework) {
        print("save experimental results \(time: Date())")
    }

    func resetExperiment(_: ExposureFramework) {
        trackThread()

        startExperimentTimer?.cancel()
        startExperimentTimer = nil
        endExperimentTimer?.cancel()
        endExperimentTimer = nil
        notificationCenter.removeAllPendingNotificationRequests()
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

    var diary: [DiaryEntry] = []

    func addDiaryEntry(_ kind: DiaryKind, _ text: String = "") {
        diary.append(DiaryEntry(Date(), kind, text))
    }

    func addMemoToDiary(_ text: String) {
        diary.append(DiaryEntry(Date(), .memo, "\"\(text)\""))
    }

    // MARK: - - Notifications

    let notificationCenter = UNUserNotificationCenter.current()

    var userNotificationAuthorization: UNAuthorizationStatus = .notDetermined

    func scheduleExperimentEndedNotification(at: Date) {
        print("Scheduling local notification for \(time: at)")
        let content = UNMutableNotificationContent()
        content.title = "GAEN Experiment ended"
        content.body = "Please return promptly to GAEN Explorer to end the experiment."
        content.categoryIdentifier = "GAEN_END_EXPERIMENT"
        content.sound = UNNotificationSound.default

        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: at)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        notificationCenter.add(request) { error in
            if let error = error {
                print("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
            } else {
                print("added experiment end notification")
            }
        }
    }

    func updateNotificationPermissions() {
        print("calling updateNotificationPermissions")
        objectWillChange.send()
        notificationCenter.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized:
                print("authorized")

            case .denied:
                print("denied")

            case .notDetermined:
                print("notDetermined")
            default:
                print("status: \(settings.authorizationStatus.rawValue)")
            }
            self.userNotificationAuthorization = settings.authorizationStatus
        }
    }

    func requestNotificationPermission() {
        print("calling requestNotificationPermission")
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, error in

            if let error = error {
                print("\(error)")

            } else {
                print("granted")
                self.updateNotificationPermissions()
            }
        }
    }

    func registerLocalNotification() {
        print("registerLocalNotification")
        guard notificationCenter.delegate == nil else {
            print("already registered")
            return
        }
        notificationCenter.getNotificationSettings { settings in
            self.userNotificationAuthorization = settings.authorizationStatus
            guard settings.authorizationStatus == .authorized else {
                print("Notification authorization status is \(settings.authorizationStatus.rawValue)")
                return
            }
            self.notificationCenter.delegate = self
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]

            self.notificationCenter.requestAuthorization(options: options) {
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
            self.notificationCenter.setNotificationCategories([endExperimentCategory])
            print("Registered GAEN_END_EXPERIMENT notification")
        }
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

    var version: String {
        let bundle = Bundle.main.infoDictionary
        guard let b = bundle else {
            return "no bundle"
        }
        return b["CFBundleShortVersionString"] as? String ?? "no version"
    }

    var build: String {
        let bundle = Bundle.main.infoDictionary
        guard let b = bundle else {
            return "no bundle"
        }
        return b["CFBundleVersion"] as? String ?? "no build"
    }

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
            if false && LocalStore.shared.viewShown != "experiment" {
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

    // __C.UIActivityType(_rawValue: com.apple.CloudDocsUI.AddToiCloudDrive)

    func csvSafe(_ txt: String) -> String {
        if txt.isEmpty {
            return ""
        }
        return "\"\(txt)\""
    }

    func myKeysCSV() -> String {
        if let keys = ExposureFramework.shared.keys?.keys {
            return keys.map { "tek, \(userName), , \($0.rollingStartNumber),  \($0.rollingPeriod), ,\($0.keyString)" }.joined(separator: "\n") + "\n"
        }
        return ""
    }

    func csvExport() -> String {
        var thresholds: [Int] = uniqueSortedThresholds() + [maxAttenuation]
        if let sample = allExposures.first?.exposures.first {
            thresholds = sample.sortedThresholds
        }

        var result = EncountersWithUser.csvHeader(thresholds)
            + allExposures.flatMap { exposure in exposure.csvFormat(owner: userName) }.joined(separator: "\n") + "\n"

        result += "device, \(userName), export, \(fullDate: Date()), \(csvSafe(deviceModelName())), handicap:, \(phoneAttenuationHandicap)\n"
        result += "version, \(userName), \(version), \(build), \(UIDevice.current.systemVersion)\n"
        result += myKeysCSV()
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
        let dateFormater = DateFormatter()
        dateFormater.dateFormat = "yyyyMMddHHmm"
        let fileName = "\(dateFormater.string(from: experimentStart ?? Date()))-\(userName).csv"

        guard let path = documents?.appendingPathComponent(fileName) else {
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
