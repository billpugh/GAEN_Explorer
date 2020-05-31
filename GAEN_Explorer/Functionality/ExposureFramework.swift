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

class ExposureFramework: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    static let shared = ExposureFramework()

    var manager = ENManager()

    var isEnabled: Bool {
        get {
            manager.exposureNotificationEnabled
        }
        set { setExposureNotificationEnabled(newValue)
        }
    }

    var status: String { getNewStatus() }

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
            && (manager.exposureNotificationStatus == .active || manager.exposureNotificationStatus == .unknown)
    }

    var active: Bool {
        ENManager.authorizationStatus == .authorized
            && manager.exposureNotificationStatus == .active
    }

    let fullDateFormatter = DateFormatter()
    let dayFormatter = DateFormatter()
    let shortDateFormatter = DateFormatter()

    var callGetTestDiagnosisKeys = false
    init() {
        print("ENManager init'd")
        if let path = Bundle.main.path(forResource: "GAEN_Explorer", ofType: ".entitlements"),
            let nsDictionary = NSDictionary(contentsOfFile: path),
            let value = nsDictionary["com.apple.developer.exposure-notification-test"] as? Bool {
            if value {
                print("using getTestDiagnosisKeys")
                self.callGetTestDiagnosisKeys = true
            }
        }

        self.signatureInfo = SignatureInfo.with { signatureInfo in
            signatureInfo.appBundleID = Bundle.main.bundleIdentifier!
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

        fullDateFormatter.dateFormat = "yyyy/MM/dd HH:mm ZZZ"
        dayFormatter.dateFormat = "MMM d"
        shortDateFormatter.timeStyle = .short
        shortDateFormatter.dateStyle = .short
        shortDateFormatter.doesRelativeDateFormatting = true

        manager.activate { _ in
            print("ENManager activiated")
            self.objectWillChange.send()
            // Ensure exposure notifications are enabled if the app is authorized. The app
            // could get into a state where it is authorized, but exposure
            // notifications are not enabled,  if the user initially denied Exposure Notifications
            // during onboarding, but then flipped on the "COVID-19 Exposure Notifications" switch
            // in Settings.
            if ENManager.authorizationStatus == .authorized, !self.manager.exposureNotificationEnabled {
                self.setExposureNotificationEnabled(true)
            }
        }
    }

    func setExposureNotificationEnabled(_ enabled: Bool) {
        if enabled != manager.exposureNotificationEnabled {
            manager.setExposureNotificationEnabled(enabled) { error in
                if let error = error {
                    print(error)
                }
                self.objectWillChange.send()
            }
        }
    }

    func getCodableKey(_ key: ENTemporaryExposureKey) -> CodableDiagnosisKey {
        CodableDiagnosisKey(key)
    }

    func getAndPackageKeys(userName: String, _ success: @escaping () -> Void) {
        if callGetTestDiagnosisKeys {
            manager.getTestDiagnosisKeys {
                temporaryExposureKeys, error in
                if let error = error {
                    print(error)
                } else {
                    let codableKeys = temporaryExposureKeys!.map { self.getCodableKey($0) }
                    print("Got \(temporaryExposureKeys!.count) diagnosis keys")
                    let package = PackagedKeys(userName: userName, date: Date(), keys: codableKeys)
                    self.package = package
                    self.keyURL = CodableDiagnosisKey.exportToURL(package: package)

                    self.objectWillChange.send()
                    success()
                }
            }
        } else {
            manager.getDiagnosisKeys {
                temporaryExposureKeys, error in
                if let error = error {
                    print(error)
                } else {
                    let codableKeys = temporaryExposureKeys!.map { self.getCodableKey($0) }
                    print("Got \(temporaryExposureKeys!.count) diagnosis keys")
                    print("Got \(codableKeys.count) codable keys")
                    let package = PackagedKeys(userName: userName, date: Date(), keys: codableKeys)
                    self.package = package
                    self.keyURL = CodableDiagnosisKey.exportToURL(package: package)
                    print("KeyURL \(self.keyURL!)")
                    self.objectWillChange.send()
                    success()
                }
            }
        }
    }

    var package: PackagedKeys?
    var keyCount: Int {
        package?.keys.count ?? -1
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
        // In a real implementation, the file at remoteURL would be downloaded from a server
        // This sample generates and saves a binary and signature pair of files based on the locally stored diagnosis keys
        let export = TemporaryExposureKeyExport.with { export in
            export.batchNum = 1
            export.batchSize = 1
            export.region = "310"
            export.signatureInfos = [self.signatureInfo]
            export.keys = diagnosisKeys.shuffled().map { diagnosisKey in
                TemporaryExposureKey.with { temporaryExposureKey in
                    temporaryExposureKey.keyData = diagnosisKey.keyData
                    temporaryExposureKey.transmissionRiskLevel = Int32(diagnosisKey.transmissionRiskLevel)
                    temporaryExposureKey.rollingStartIntervalNumber = Int32(diagnosisKey.rollingStartNumber)
                    temporaryExposureKey.rollingPeriod = Int32(diagnosisKey.rollingPeriod)
                }
            }
        }
        return "EK Export v1    ".data(using: .utf8)! + (try export.serializedData())
    }

    func getTEKSignatureList(_ exportData: Data) throws -> TEKSignatureList {
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

    func importData(from url: URL, completionHandler: ((Bool) -> Void)? = nil) {
        analysisQueue.async {
            print("got url \(url)")
            do {
                let data = try Data(contentsOf: url)
                let packagedKeys = try JSONDecoder().decode(PackagedKeys.self, from: data)

                LocalStore.shared.addKeysFromUser(packagedKeys)
            } catch {
                print("Unexpected error: \(error)")
                completionHandler?(false)
            }
        }
    }

    func getURLs(_ exportData: Data, _ tekSignatureList: TEKSignatureList) throws -> [URL] {
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

    func getExposureInfo(keys: [CodableDiagnosisKey], userExplanation: String, configuration: CodableExposureConfiguration) throws -> [CodableExposureInfo] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: [CodableExposureInfo]?
        var exposureDetectionError: Error?
        let URLs = try getURLs(diagnosisKeys: keys)
        print("Calling detect exposures")
        ExposureFramework.shared.manager.detectExposures(configuration: configuration.asExposureConfiguration(), diagnosisKeyURLs: URLs) {
            summary, error in
            if let error = error {
                print("error description \(error.localizedDescription)")
                exposureDetectionError = error
                semaphore.signal()
                return
            }
            print("Calling getExposureInfo")
            ExposureFramework.shared.manager.getExposureInfo(summary: summary!, userExplanation: userExplanation) { exposures, error in
                if let error = error {
                    print("error description \(error.localizedDescription)")
                    exposureDetectionError = error
                    semaphore.signal()
                    return
                }
                result = exposures!.map { exposure in CodableExposureInfo(exposure, config: configuration) }.sorted { $0.date > $1.date }
                semaphore.signal()
            }
        } // detectExposures
        semaphore.wait()
        if let error = exposureDetectionError {
            print("getExposureInfo failed error:  \(error.localizedDescription)")
            throw error
        }
        return result!
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
                                subjectForActivityType _: UIActivity.ActivityType?) -> String {
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
