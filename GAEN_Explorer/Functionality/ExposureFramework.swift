/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 A class that manages a singleton ENManager object.
 */

import Combine
import CommonCrypto
import ExposureNotification
import Foundation
import LinkPresentation
import os.log

let pointsOfInterest = OSLog(subsystem: "com.ninjamonkeycoders.gaen", category: .pointsOfInterest)

class ExposureFramework: ObservableObject {
    static let packagedKeysKey = "packagedKeys"
    let objectWillChange = ObservableObjectPublisher()

    static let shared = ExposureFramework()

    static func isV2() -> Bool {
        let version = Bundle.main.object(forInfoDictionaryKey: "ENAPIVersion") as! String
        return version == "2"
    }

    var manager = ENManager()

    var permission: ENAuthorizationStatus {
        ENManager.authorizationStatus
    }

    var becomeActiveObserver: NSObjectProtocol?

    @Published
    var observedIsEnabled: Bool = false {
        willSet {
            isEnabled = newValue
            print("Changed observedIsEnabled to \(newValue)")
        }
    }

    var isEnabled: Bool {
        get {
            manager.exposureNotificationEnabled
        }
        set {
            if manager.exposureNotificationEnabled == newValue {
                print("isEnabled is already \(newValue)")
                return
            }

            print("changing isEnabled \(manager.exposureNotificationEnabled) to \(newValue)")

            setExposureNotificationEnabled(newValue) { changed in
                guard changed else {
                    print("isEnabled didn't need to be changed")
                    return
                }
                DispatchQueue.main.async {
                    if newValue {
                        self.exposureLogsErased = false
                        print("Marking exposureLogs erased to false")
                    }
                    print("Changing observedIsEnabled to \(newValue)")
                    // self.observedIsEnabled = newValue
                    LocalStore.shared.addDiaryEntry(.scanningChanged, "\(newValue)")
                }
            }
        }
    }

    func requestENPermission() {
        print("requesting en permission")
        objectWillChange.send()
        switch ENManager.authorizationStatus {
        case .unknown:
            manager.setExposureNotificationEnabled(true) { error in
                if let error = error {
                    print("Error: \(error)")
                }
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            }
        case .authorized:
            print("en already authorized")
        case .notAuthorized:
            print("en denied")
        case .restricted:
            print("en restricted")
        default:
            print("unknown ENManager.authorizationStatus")
        }
    }

    func setExposureNotificationEnabledSync(_ enabled: Bool) {
        assert(!Thread.current.isMainThread)
        let wasEnabled = manager.exposureNotificationEnabled
        if wasEnabled == enabled { return }
        let semaphore = DispatchSemaphore(value: 0)
        manager.setExposureNotificationEnabled(enabled) { error in
            if let error = error {
                print(error)
            }
            print("Finished changing enabled sync from \(wasEnabled) to \(self.manager.exposureNotificationEnabled)")
            semaphore.signal()
        }
        semaphore.wait()
    }

    func setExposureNotificationEnabled(_ enabled: Bool, after: @escaping (Bool) -> Void) {
        let wasEnabled = manager.exposureNotificationEnabled
        print("Setting enabled to \(enabled)")
        guard enabled != wasEnabled else {
            print("Already set enabled to \(wasEnabled)")
            after(false)
            return
        }
        print("Changing enabled to \(enabled)")
        manager.setExposureNotificationEnabled(enabled) { error in
            if let error = error {
                print(error)
            }
            print("Finished changing enabled to \(self.manager.exposureNotificationEnabled)")
            after(true)
        }
    }

    var status: String { getNewStatus() }

    @Published var exposureLogsErased: Bool = false

    var canEraseExposureLogs: Bool {
        !exposureLogsErased && !isEnabled
    }

    func eraseExposureLogs() {
        assert(!isEnabled)
        exposureLogsErased = true
        prevKeys = keys
        keys = nil
        UIApplication.shared.open(URL(string: "App-prefs:root=Privacy")!)
    }

    var exposureNotificationStatus: ENStatus {
        manager.exposureNotificationStatus
    }

    var authorizationStatus: ENAuthorizationStatus {
        ENManager.authorizationStatus
    }

    func getNewStatus() -> String {
        "\(manager.exposureNotificationEnabled ? "Enabled" : "Disabled") \(manager.exposureNotificationStatus) \(ENManager.authorizationStatus)"
    }

    var feasible: Bool {
        (ENManager.authorizationStatus == .authorized || ENManager.authorizationStatus == .unknown)
    }

    var active: Bool {
        ENManager.authorizationStatus == .authorized
            && manager.exposureNotificationStatus == .active
    }

    var callGetTestDiagnosisKeys = false
    init() {
        print("ENManager init'd")
        if let path = Bundle.main.path(forResource: "GAEN_Explorer", ofType: ".entitlements"),
            let nsDictionary = NSDictionary(contentsOfFile: path),
            let value = nsDictionary["com.apple.developer.exposure-notification-test"] as? Bool
        {
            if value {
                print("using getTestDiagnosisKeys")
                self.callGetTestDiagnosisKeys = true
            }
        }

        if ExposureFramework.isV2() {
            print("Using v2 API")
        } else {
            print("Using v1 API")
        }
        self.signatureInfo = SignatureInfo.with { signatureInfo in
            signatureInfo.verificationKeyVersion = "v1"
            signatureInfo.verificationKeyID = "310"
            signatureInfo.signatureAlgorithm = "SHA256withECDSA"
        }
        var cfError: Unmanaged<CFError>?
        let attributes = [
            kSecAttrKeyType: kSecAttrKeyTypeEC,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits: 256,
        ] as CFDictionary
        self.privateKeyData = privateKeyECData.suffix(65) + privateKeyECData.subdata(in: 36 ..< 68)
        self.secKey = SecKeyCreateWithData(privateKeyData as CFData, attributes, &cfError)!

        if let keyData = UserDefaults.standard.object(forKey: Self.packagedKeysKey) as? Data {
            self.keys = try? JSONDecoder().decode(PackagedKeys.self, from: keyData)
        }

        manager.activate { _ in
            print("ENManager activiated")
            print("Authorized: \(ENManager.authorizationStatus)")

            if ENManager.authorizationStatus == .authorized, !self.manager.exposureNotificationEnabled {
                self.manager.setExposureNotificationEnabled(true) { _ in
                    print("turned on \(self.manager.exposureNotificationEnabled)")
                }
            }
        }
        self.observedIsEnabled = isEnabled
        let center = NotificationCenter.default
        let mainQueue = OperationQueue.main
        self.becomeActiveObserver = center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: mainQueue) { _ in
            print("framework become active")
            self.observedIsEnabled = self.isEnabled
        }
    }

    func getCodableKey(_ key: ENTemporaryExposureKey) -> CodableDiagnosisKey {
        CodableDiagnosisKey(key)
    }

    var currentRollingStartDate: Int {
        rollingStartNumber(Date())
    }

    func rollingStartNumber(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 / (24 * 60 * 60)) * 144
    }

    var keys: PackagedKeys?

    var prevKeys: PackagedKeys?

    var keysAreCurrent: Bool {
        guard let p = keys else { return false }
        return keysCurrent(p)
    }

    func keysCurrent(_ p: PackagedKeys) -> Bool {
        let currentRollingStart = currentRollingStartDate
        return !p.keys.filter { $0.rollingStartNumber == currentRollingStart }.isEmpty
    }

    func verifyKeysAreNew() -> Bool {
        if let k = keys,
            let prev = prevKeys
        {
            for pKey in prev.keys {
                let matchingKeys = k.keys.filter { $0.keyData == pKey.keyData && $0.rollingStartNumber == pKey.rollingStartNumber }
                if !matchingKeys.isEmpty {
                    print("found \(matchingKeys.count) matching keys")
                    exposureLogsErased = false
                    return false
                }
            } // for pKey
        } // if let
        prevKeys = nil
        return true
    }

    func currentKeys(_ userName: String, result: @escaping (PackagedKeys) -> Void) {
        if let p = keys,
            keysCurrent(p)
        {
            result(p)
            return
        }
        let wasEnabled = isEnabled
        setExposureNotificationEnabled(true) { _ in
            if self.callGetTestDiagnosisKeys {
                self.manager.getTestDiagnosisKeys {
                    temporaryExposureKeys, error in
                    self.packageKeys(userName, temporaryExposureKeys, wasEnabled: wasEnabled, error, result)
                }
            } else {
                print("Calling self.manager.getDiagnosisKeys")
                self.manager.getDiagnosisKeys {
                    temporaryExposureKeys, error in
                    self.packageKeys(userName, temporaryExposureKeys, wasEnabled: wasEnabled, error, result)
                }
            }
        }
    }

    func packageKeys(_ userName: String, _ temporaryExposureKeys: [ENTemporaryExposureKey]?,
                     wasEnabled: Bool,
                     _ error: Error?,
                     _ result: @escaping (PackagedKeys) -> Void)
    {
        isEnabled = wasEnabled
        DispatchQueue.main.async {
            if let e = error {
                print(e)
                result(PackagedKeys(userName: userName, dateKeysSent: Date(), keys: []))
            } else {
                let codableKeys = temporaryExposureKeys!.map { self.getCodableKey($0) }
                print("Got \(temporaryExposureKeys!.count) diagnosis keys")
                let newKeys = PackagedKeys(userName: userName, dateKeysSent: Date(), keys: codableKeys)

                self.updateKeys(newKeys)
                result(newKeys)
            }
        }
    }

    func updateKeys(_ keys: PackagedKeys) {
        // assert(keysCurrent(keys) || !callGetTestDiagnosisKeys)
        objectWillChange.send()
        self.keys = keys
        if let encoded = try? JSONEncoder().encode(keys) {
            UserDefaults.standard.set(encoded, forKey: Self.packagedKeysKey)
        }
    }

    func exportAllKeys(userName: String, otherKeys: [PackagedKeys], _ result: @escaping (URL?) -> Void) {
        currentKeys(userName) { p in
            self.keyURL = CodableDiagnosisKey.exportToURL(packages: otherKeys + [p])
            result(self.keyURL)
        }
    }

    var keyCount: Int {
        guard let p = keys else { return 0 }
        return p.keys.count
    }

    var keysExportedMessage: String {
        switch keyCount {
        case -1: return ""
        case 0: return "(no keys exported)"
        case 1: return "(1 key exported)"
        default: return "(\(keyCount) keys exported)"
        }
    }

    var keyURL: URL?

    deinit {
        manager.invalidate()
    }

    // NOTE: The backslash on the end of the first line is not part of the key
    private let privateKeyECData = Data(base64Encoded: """
    MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgKJNe9P8hzcbVkoOYM4hJFkLERNKvtC8B40Y/BNpfxMeh\
    RANCAASfuKEs4Z9gHY23AtuMv1PvDcp4Uiz6lTbA/p77if0yO2nXBL7th8TUbdHOsUridfBZ09JqNQYKtaU9BalkyodM
    """)!

    private var privateKeyData: Data
    private var signatureInfo: SignatureInfo
    private var secKey: SecKey

    func getExportData(_ diagnosisKeys: [CodableDiagnosisKey]) throws -> Data {
        os_signpost(.begin, log: pointsOfInterest, name: "getExportData")
        defer {
            os_signpost(.end, log: pointsOfInterest, name: "getExportData")
        }
        // In a real implementation, the file at remoteURL would be downloaded from a server
        // This sample generates and saves a binary and signature pair of files based on the locally stored diagnosis keys
        let export = TemporaryExposureKeyExport.with { export in
            export.batchNum = 1
            export.batchSize = 1
            export.region = "310"
            export.signatureInfos = [self.signatureInfo]
            export.keys = diagnosisKeys.shuffled().map { diagnosisKey in
                TemporaryExposureKey.with { temporaryExposureKey in
                    print("TEK: Rolling start \(diagnosisKey.rollingStartNumber), period \(diagnosisKey.rollingPeriod)")
                    temporaryExposureKey.keyData = diagnosisKey.keyData
                    temporaryExposureKey.transmissionRiskLevel = Int32(diagnosisKey.transmissionRiskLevel)
                    if (true || diagnosisKey.transmissionRiskLevel > 0) {
                    temporaryExposureKey.reportType = .confirmedTest
//                    temporaryExposureKey.daysSinceOnsetOfSymptoms = 0
                    }
                    temporaryExposureKey.rollingStartIntervalNumber = Int32(diagnosisKey.rollingStartNumber)
                    temporaryExposureKey.rollingPeriod = Int32(diagnosisKey.rollingPeriod)
                    print(temporaryExposureKey.debugDescription)
                }
            }
        }
        return "EK Export v1    ".data(using: .utf8)! + (try export.serializedData())
    }

    func getTEKSignatureList(_ exportData: Data) throws -> TEKSignatureList {
        os_signpost(.begin, log: pointsOfInterest, name: "getSignatures")
        defer {
            os_signpost(.end, log: pointsOfInterest, name: "getSignatures")
        }
        var exportHash = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = exportData.withUnsafeBytes { exportDataBuffer in
            exportHash.withUnsafeMutableBytes { exportHashBuffer in
                CC_SHA256(exportDataBuffer.baseAddress, CC_LONG(exportDataBuffer.count), exportHashBuffer.bindMemory(to: UInt8.self).baseAddress)
            }
        }
        var cfError: Unmanaged<CFError>?

        guard let signedHash = SecKeyCreateSignature(secKey, .ecdsaSignatureDigestX962SHA256, exportHash as CFData, &cfError) as Data? else {
            throw cfError!.takeRetainedValue()
        }

        return TEKSignatureList.with { tekSignatureList in
            tekSignatureList.signatures = [TEKSignature.with { tekSignature in
                tekSignature.signatureInfo = signatureInfo
                tekSignature.signature = signedHash
                tekSignature.batchNum = 1
                tekSignature.batchSize = 1
            }]
        }
    }

    let standardUserExplanation = NSLocalizedString("USER_NOTIFICATION_EXPLANATION", comment: "User notification")
    let analysisQueue = DispatchQueue(label: "com.ninjamonkeycoders.gaen.analysis", attributes: .concurrent)

    func getURLs(_ exportData: Data, _ tekSignatureList: TEKSignatureList) throws -> [URL] {
        os_signpost(.begin, log: pointsOfInterest, name: "createFiles")
        defer {
            os_signpost(.end, log: pointsOfInterest, name: "createFiles")
        }
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!

        let localBinURL = cachesDirectory.appendingPathComponent("export.bin")
        try exportData.write(to: localBinURL)

        let localSigURL = cachesDirectory.appendingPathComponent("export.sig")
        try tekSignatureList.serializedData().write(to: localSigURL)
        return [localBinURL, localSigURL]
    }

    func getURLs(diagnosisKeys: [CodableDiagnosisKey]) throws -> [URL] {
        let exportData = try getExportData(diagnosisKeys)

        let tekSignatureList = try getTEKSignatureList(exportData)

        return try getURLs(exportData, tekSignatureList)
    }

    //    func analyze(packagedKeys: PackagedKeys) {
    //        print("starting analysis")
    //        analysisQueue.async {
    //            do {
    //                let analysis = ExposureAnalysis(name: packagedKeys.userName)
    //                for pass in 0 ..< numberAnalysisPasses {
    //                    print("pass \(pass)")
    //                    let config = CodableExposureConfiguration.getCodableExposureConfiguration(pass: pass)
    //
    //                    analysis.analyze(pass: pass, exposures: try self.getExposureInfo(packagedKeys: packagedKeys, userExplanation: "Analyzing exposures, pass \(pass) of \(numberAnalysisPasses)", configuration: config))
    //                }
    //                analysis.printMe()
    //            } catch {
    //                print("\(error)")
    //            }
    //        }
    //    }

    fileprivate func printSummaries(_ summary: ENExposureDetectionSummary) {
        print("\(summary.daySummaries.count) day summaries")
        for day in summary.daySummaries {
            print("Day \(day: day.date)")
            print("time since 1970 = \(day.date.timeIntervalSince1970)")

            let item = day.daySummary
            print(" maxScore: \(item.maximumScore)")
            print(" sumScore: \(item.scoreSum)")
            print(" weightedDurationSum: \(item.weightedDurationSum)")
        }
    }

    func getBucket(attn: ENAttenuation, thresholds: [NSNumber]) -> Int {
        for b in 0 ..< thresholds.count {
            if attn <= thresholds[b].intValue {
                return b
            }
        }
        return thresholds.count
    }

    fileprivate func printWindows(_ summary: ENExposureDetectionSummary, _ windows: [ENExposureWindow], thresholds: [NSNumber]) {
        var totalSeconds = 0
        print("total of \(windows.count) exposure windows")
        for day in summary.daySummaries {
            var dayDurations = [0, 0, 0, 0]
            print("\n\nDay \(day: day.date)")
            print("time since 1970 = \(day.date.timeIntervalSince1970)")
            for i in 0 ..< windows.count {
                let w = windows[i]
                if w.date != day.date {
                    continue
                }
                var durations = [0, 0, 0, 0]

                print("\nWindow # \(i)")
                print("Day \(day: w.date)")
                print("time since 1970 = \(w.date.timeIntervalSince1970)")
                var windowSeconds = 0
                for scan in w.scanInstances {
                    windowSeconds += scan.secondsSinceLastScan
                    print(" \(scan.minimumAttenuation) - \(scan.typicalAttenuation) dB for \(scan.secondsSinceLastScan) seconds")
                    durations[getBucket(attn: scan.typicalAttenuation, thresholds: thresholds)] += scan.secondsSinceLastScan
                    dayDurations[getBucket(attn: scan.typicalAttenuation, thresholds: thresholds)] += scan.secondsSinceLastScan
                }
                totalSeconds += windowSeconds
                print("window seconds \(windowSeconds)")
                print("durations: \(durations)")
            } // for w
            print("day seconds \(totalSeconds)")
            print("day durations: \(dayDurations)")
        }
        print()
    }
    

    func getExposureInfoSync(keys: [CodableDiagnosisKey],
                             userExplanation: String,
                             _ parameters: AnalysisParameters,
                             configuration: CodableExposureConfiguration) throws
        -> [CodableExposureInfo]
    {
        assert(!Thread.current.isMainThread)
        var result: [CodableExposureInfo]?
        var resultError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        let URLs = try getURLs(diagnosisKeys: keys)
        print("Calling detect exposures with \(keys.count) keys")

        os_signpost(.begin, log: pointsOfInterest, name: "detectExposures")

        let config = configuration.asExposureConfiguration()
        print("attenuationLevelValues \(config.attenuationLevelValues)")
        print("attenuationDurationThresholds \(config.attenuationDurationThresholds)")
        if ExposureFramework.isV2() {
            print("\n\nCached exposures")
            ExposureFramework.shared.manager.detectExposures(configuration: config) {
                summary, error in
                if let error = error {
                    print("error description \(error.localizedDescription)")

                    resultError = error
                    semaphore.signal()
                    return
                }
                self.printSummaries(summary!)
                ExposureFramework.shared.manager.getExposureWindows(summary: summary!) { windows, error in
                    if let error = error {
                        print("error description \(error.localizedDescription)")

                        resultError = error
                        semaphore.signal()
                        return
                    }
                    self.printWindows(summary!, windows!, thresholds: config.attenuationDurationThresholds)
                    print("\n\nWith new keys")
                    ExposureFramework.shared.manager.detectExposures(configuration: config, diagnosisKeyURLs: URLs) {
                        summary, error in
                        os_signpost(.end, log: pointsOfInterest, name: "detectExposures")
                        if let error = error {
                            print("error description \(error.localizedDescription)")

                            resultError = error
                            semaphore.signal()
                            return
                        }

                        self.printSummaries(summary!)
                        ExposureFramework.shared.manager.getExposureWindows(summary: summary!) { windows, error in
                            if let error = error {
                                print("error description \(error.localizedDescription)")

                                resultError = error
                                semaphore.signal()
                                return
                            }
                            self.printWindows(summary!, windows!, thresholds: config.attenuationDurationThresholds)
                            result = []
                            semaphore.signal()
                        }
                        return
                    }
                }
            }
            semaphore.wait()
            if let result = result {
                return result
            }
            throw resultError!
        }

        ExposureFramework.shared.manager.detectExposures(configuration: config, diagnosisKeyURLs: URLs) {
            summary, error in
            os_signpost(.end, log: pointsOfInterest, name: "detectExposures")
            if let error = error {
                print("error description \(error.localizedDescription)")

                resultError = error
                semaphore.signal()
                return
            }

            print("maximum risk score \(summary!.maximumRiskScore), \(summary!.maximumRiskScoreFullRange)")
            print("sum risk score \(summary!.riskScoreSumFullRange)")
            print("matched key count is \(summary!.matchedKeyCount)")
            print("atteunation durations is \(summary!.attenuationDurations)")
            print("Days since last exposure is \(summary!.daysSinceLastExposure)")
            if summary?.matchedKeyCount == 0 {
                print("No keys matched, skipping getExposureInfo")
                result = []
                semaphore.signal()
                return
            }
            print("Calling getExposureInfo, true duration is \(parameters.trueDuration)")
            os_signpost(.begin, log: pointsOfInterest, name: "getExposureInfo")

            ExposureFramework.shared.manager.getExposureInfo(summary: summary!, userExplanation: userExplanation) { exposures, error in
                os_signpost(.end, log: pointsOfInterest, name: "getExposureInfo")
                if let error = error {
                    print("error description \(error.localizedDescription)")
                    resultError = error
                    semaphore.signal()
                    return
                }
                result = exposures!.map { exposure in CodableExposureInfo(exposure, trueDuration: parameters.trueDuration, config: configuration) }.sorted { $0.date > $1.date }
                semaphore.signal()
                return
            }
        } // detectExposures

        semaphore.wait()
        if let result = result {
            return result
        }
        throw resultError!
    }

    func getExposureInfo(keys: [CodableDiagnosisKey], userExplanation: String, parameters: AnalysisParameters = AnalysisParameters(), configuration: CodableExposureConfiguration, block: @escaping ([CodableExposureInfo]?, Error?) -> Void) throws {
        let URLs = try getURLs(diagnosisKeys: keys)
        print("Calling  detect exposures with \(keys.count) keys")
        if false {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            keys.forEach { key in
                print("\(String(data: try! encoder.encode(key), encoding: .utf8)!)")
            }
        }

        os_signpost(.begin, log: pointsOfInterest, name: "detectExposures")

        ExposureFramework.shared.manager.detectExposures(configuration: configuration.asExposureConfiguration(), diagnosisKeyURLs: URLs) {
            summary, error in
            os_signpost(.end, log: pointsOfInterest, name: "detectExposures")
            if let error = error {
                print("error description \(error.localizedDescription)")

                block(nil, error)
                return
            }
            if summary?.matchedKeyCount == 0 {
                print("No keys matched, skipping getExposureInfo")
                block(nil, error)
                return
            }
            print("Calling getExposureInfo")
            os_signpost(.begin, log: pointsOfInterest, name: "getExposureInfo")

            ExposureFramework.shared.manager.getExposureInfo(summary: summary!, userExplanation: userExplanation) { exposures, error in
                os_signpost(.end, log: pointsOfInterest, name: "getExposureInfo")
                if let error = error {
                    print("error description \(error.localizedDescription)")
                    block(nil, error)
                    return
                }
                let result = exposures!.map { exposure in CodableExposureInfo(exposure, trueDuration: parameters.trueDuration, config: configuration) }.sorted { $0.date > $1.date }
                block(result, nil)
            }
        } // detectExposures
    }

    func analyzeRandomKeys(numKeys: Int) {
        print("Calling analyzeRandomKeys \(numKeys)")
        analysisQueue.async {
            os_signpost(.begin, log: pointsOfInterest, name: "generateRandomKeys")
            var keys: [CodableDiagnosisKey] = []
            for i in 1 ... numKeys {
                keys.append(CodableDiagnosisKey(randomFromDaysAgo: UInt32(1 + (i % 10))))
            }
            print("have \(keys.count) random keys")
            os_signpost(.end, log: pointsOfInterest, name: "generateRandomKeys")
            try! self.getExposureInfo(keys: keys, userExplanation: "Analyzing random keys", configuration: CodableExposureConfiguration.getCodableExposureConfiguration(pass: 1)) { exposures, _ in
                print("Found \(exposures?.count ?? 0) exposures")
            }
        }
    }
}

extension ENStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown:
            return NSLocalizedString("EN Unknown Status", comment: "")
        case .active:
            return NSLocalizedString("EN Active", comment: "")
        case .disabled:
            return NSLocalizedString("EN Disabled", comment: "")
        case .bluetoothOff:
            return NSLocalizedString("Bluetooth is Off", comment: "")
        case .restricted:
            return NSLocalizedString("EN Restricted", comment: "")
        @unknown default:
            return ""
        }
    }

    public var detailedDescription: String {
        switch self {
        case .unknown:
            return NSLocalizedString("Status of Exposure Notification is unknown.", comment: "")
        case .active:
            return NSLocalizedString("Exposure Notification is active on the system.", comment: "")
        case .disabled:
            return NSLocalizedString("Exposure Notification is disabled.", comment: "")
        case .bluetoothOff:
            return NSLocalizedString("Bluetooth has been turned off on the system. Bluetooth is required for Exposure Notification.", comment: "")
        case .restricted:
            return NSLocalizedString("Exposure Notification is not active due to system restrictions, such as parental controls.", comment: "")
        @unknown default:
            return ""
        }
    }
}

extension ENAuthorizationStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown:
            return NSLocalizedString("Authorized not requested", comment: "")
        case .authorized:
            return NSLocalizedString("Authorized", comment: "")
        case .notAuthorized:
            return NSLocalizedString("not Authorized", comment: "")
        case .restricted:
            return NSLocalizedString("Authorization restricted", comment: "")
        @unknown default:
            return ""
        }
    }

    public var detailedDescription: String {
        switch self {
        case .unknown:
            return NSLocalizedString("Authorized not requested", comment: "")
        case .authorized:
            return NSLocalizedString("Authorized", comment: "")
        case .notAuthorized:
            return NSLocalizedString("not Authorized", comment: "")
        case .restricted:
            return NSLocalizedString("Authorization restricted", comment: "")
        @unknown default:
            return ""
        }
    }
}

class DiagnosisKeyItem: NSObject, UIActivityItemSource {
    let keyCount: Int
    let userName: String
    let url: URL
    let title: String

    init(_ k: Int, _ user: String, _ url: URL) {
        self.keyCount = k
        self.userName = user
        self.url = url
        self.title = keyCount == 1 ? "a diagnosis key for \(userName) from GAEN Explorer" : "\(keyCount) diagnosis keys for \(userName) from GAEN Explorer"
    }

    func itemsToShare() -> [Any] {
        [title, self]
    }

    func activityViewControllerPlaceholderItem(_: UIActivityViewController) -> Any {
        "Diagnosis keys"
    }

    func activityViewController(_: UIActivityViewController, itemForActivityType _: UIActivity.ActivityType?) -> Any? {
        url
    }

    func activityViewController(_: UIActivityViewController,
                                subjectForActivityType _: UIActivity.ActivityType?) -> String
    {
        title
    }

    func activityViewControllerLinkMetadata(_: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = url
        let iconURL = Bundle.main.url(forResource: "keys_64", withExtension: "png")
        metadata.iconProvider = NSItemProvider(contentsOf: iconURL)

        metadata.title = title
        return metadata
    }
}
