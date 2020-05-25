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

private let attenuationDurationThresholdsKey = "attenuationDurationThresholds"

extension ENExposureConfiguration {
    var attenuationDurationThresholds: NSArray? {
        get {
            value(forKey: attenuationDurationThresholdsKey) as? NSArray
        }
        set(levels) {
            setValue(levels, forKey: attenuationDurationThresholdsKey)
        }
    }
}

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
    let dateF = DateFormatter()
    let dateFr = DateFormatter()
    let dateTimeFr = DateFormatter()

    func doneAnalyzingKeys() {
        print("done analyzing keys")
    }

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

        dateF.dateFormat = "yyyy/MM/dd HH:mm ZZZ"
        dateFr.dateFormat = "MMM d"
        dateTimeFr.timeStyle = .short
        dateTimeFr.dateStyle = .short
        dateTimeFr.doesRelativeDateFormatting = true

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

    func getCodableKey(_ key: ENTemporaryExposureKey, _ tRisk: ENRiskLevel) -> CodableDiagnosisKey {
        CodableDiagnosisKey(key, tRiskLevel: tRisk)
    }

    func getAndPackageKeys(userName: String, tRiskLevel: ENRiskLevel, _ success: @escaping () -> Void) {
        if callGetTestDiagnosisKeys {
            manager.getTestDiagnosisKeys {
                temporaryExposureKeys, error in
                if let error = error {
                    print(error)
                } else {
                    let codableKeys = temporaryExposureKeys!.map { self.getCodableKey($0, tRiskLevel) }
                    print("Got \(temporaryExposureKeys!.count) diagnosis keys")
                    print("Got \(codableKeys.count) codable keys")
                    self.package = PackagedKeys(userName: userName, date: Date(), keys: codableKeys)
                    success()
                }
            }
        } else {
            manager.getDiagnosisKeys {
                temporaryExposureKeys, error in
                if let error = error {
                    print(error)
                } else {
                    let codableKeys = temporaryExposureKeys!.map { self.getCodableKey($0, tRiskLevel) }
                    print("Got \(temporaryExposureKeys!.count) diagnosis keys")
                    print("Got \(codableKeys.count) codable keys")
                    self.package = PackagedKeys(userName: userName, date: Date(), keys: codableKeys)
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

    var keyURL: URL {
        CodableDiagnosisKey.exportToURL(package: package!)!
    }

    var showingSheet = false

    deinit {
        manager.invalidate()
    }

    // NOTE: The backslash on the end of the first line is not part of the key
    private static let privateKeyECData = Data(base64Encoded: """
    MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgKJNe9P8hzcbVkoOYM4hJFkLERNKvtC8B40Y/BNpfxMeh\
    RANCAASfuKEs4Z9gHY23AtuMv1PvDcp4Uiz6lTbA/p77if0yO2nXBL7th8TUbdHOsUridfBZ09JqNQYKtaU9BalkyodM
    """)!

    static func importData(from url: URL, completionHandler: ((Bool) -> Void)? = nil) -> Progress {
        let progress = Progress()
        do {
            let data = try Data(contentsOf: url)
            let packagedKeys = try JSONDecoder().decode(PackagedKeys.self, from: data)
            let diagnosisKeys = packagedKeys.keys

            let attributes = [
                kSecAttrKeyType: kSecAttrKeyTypeEC,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate,
                kSecAttrKeySizeInBits: 256,
            ] as CFDictionary

            var cfError: Unmanaged<CFError>?

            let privateKeyData = privateKeyECData.suffix(65) + privateKeyECData.subdata(in: 36 ..< 68)
            guard let secKey = SecKeyCreateWithData(privateKeyData as CFData, attributes, &cfError) else {
                throw cfError!.takeRetainedValue()
            }

            let signatureInfo = SignatureInfo.with { signatureInfo in
                signatureInfo.appBundleID = Bundle.main.bundleIdentifier!
                signatureInfo.verificationKeyVersion = "v1"
                signatureInfo.verificationKeyID = "310"
                signatureInfo.signatureAlgorithm = "SHA256withECDSA"
            }

            // In a real implementation, the file at remoteURL would be downloaded from a server
            // This sample generates and saves a binary and signature pair of files based on the locally stored diagnosis keys
            let export = TemporaryExposureKeyExport.with { export in
                export.batchNum = 1
                export.batchSize = 1
                export.region = "310"
                export.signatureInfos = [signatureInfo]
                export.keys = diagnosisKeys.shuffled().map { diagnosisKey in
                    TemporaryExposureKey.with { temporaryExposureKey in
                        temporaryExposureKey.keyData = diagnosisKey.keyData
                        temporaryExposureKey.transmissionRiskLevel = Int32(diagnosisKey.transmissionRiskLevel)
                        temporaryExposureKey.rollingStartIntervalNumber = Int32(diagnosisKey.rollingStartNumber)
                        temporaryExposureKey.rollingPeriod = Int32(diagnosisKey.rollingPeriod)
                    }
                }
            }

            let exportData = "EK Export v1    ".data(using: .utf8)! + (try export.serializedData())

            var exportHash = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
            _ = exportData.withUnsafeBytes { exportDataBuffer in
                exportHash.withUnsafeMutableBytes { exportHashBuffer in
                    CC_SHA256(exportDataBuffer.baseAddress, CC_LONG(exportDataBuffer.count), exportHashBuffer.bindMemory(to: UInt8.self).baseAddress)
                }
            }

            guard let signedHash = SecKeyCreateSignature(secKey, .ecdsaSignatureDigestX962SHA256, exportHash as CFData, &cfError) as Data? else {
                throw cfError!.takeRetainedValue()
            }

            let tekSignatureList = TEKSignatureList.with { tekSignatureList in
                tekSignatureList.signatures = [TEKSignature.with { tekSignature in
                    tekSignature.signatureInfo = signatureInfo
                    tekSignature.signature = signedHash
                    tekSignature.batchNum = 1
                    tekSignature.batchSize = 1
                    }]
            }

            let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!

            let localBinURL = cachesDirectory.appendingPathComponent("export.bin")
            try exportData.write(to: localBinURL)

            let localSigURL = cachesDirectory.appendingPathComponent("export.sig")
            try tekSignatureList.serializedData().write(to: localSigURL)

            func finish(_ result: Result<[CodableExposureInfo], Error>) {
                // try? FileManager.default.removeItem(at: localBinURL)
                // try? FileManager.default.removeItem(at: localSigURL)

                print("finish called")
                let success: Bool
                if progress.isCancelled {
                    success = false
                } else {
                    switch result {
                    case let .success(newExposures):
                        print("Got \(newExposures.count) new exposures")
                        success = true
                    case let .failure(error):
                        print("Got failure 123 \(error)")

                        success = false
                    }
                }

                completionHandler?(success)
            }

            let config = CodableExposureConfiguration.shared
            let URLS = [localBinURL, localSigURL]
            print("Checking for keys in \(URLS)")
            print("Got config")
            ExposureFramework.shared.manager.detectExposures(configuration: config.asExposureConfiguration(), diagnosisKeyURLs: URLS) { summary,
                error in
                if let error = error {
                    print("error description \(error.localizedDescription)")
                    LocalStore.shared.appendExposure(BatchExposureInfo(userName: error.localizedDescription, dateKeysSent: Date(), dateProcessed: Date(), exposures: []))

                    ExposureFramework.shared.doneAnalyzingKeys()
                    finish(.failure(error))
                    return
                }
                print("Found exposures \(summary!.matchedKeyCount)")
                print("Found exposures \(summary!.daysSinceLastExposure) days ago")
                print("maximum risk score \(summary!.maximumRiskScore) ")
                print("attenuationDurations \(summary!.attenuationDurations) ")
                print("  metadata:")
                for (key, value) in summary!.metadata! {
                    print("    \(key) : \(type(of: value)) = \(value)")
                }

                let userExplanation = NSLocalizedString("USER_NOTIFICATION_EXPLANATION", comment: "User notification")
                ExposureFramework.shared.manager.getExposureInfo(summary: summary!, userExplanation: userExplanation) { exposures, error in
                    if let error = error {
                        ExposureFramework.shared.doneAnalyzingKeys()
                        finish(.failure(error))
                        return
                    }

                    exposures!.forEach { exposure in
                        let day = ExposureFramework.shared.dateF.string(from: exposure.date)
                        print("Exposure \(Int(exposure.duration / 60))on \(day)")
                        print("was \(ExposureFramework.shared.dateFr.string(from: exposure.date))")
                        print("Raw date \(exposure.date.timeIntervalSince1970)")
                        print("attn \(exposure.attenuationValue) ")
                        print("transmission risk \(exposure.transmissionRiskLevel) ")
                        print("total risk \(exposure.totalRiskScore) ")
                        print("attenuationDurations \(exposure.attenuationDurations.map { Int(truncating: $0) / 60 }) ")
                        print("metadata \(exposure.metadata!) ")

                        print()
                    }
                    let newExposures = exposures!.map { exposure in CodableExposureInfo(exposure) }.sorted { $0.date > $1.date }
                    LocalStore.shared.appendExposure(
                        BatchExposureInfo(userName: packagedKeys.userName,
                                          dateKeysSent: packagedKeys.date,
                                          dateProcessed: Date(),
                                          config: config,
                                          exposures: newExposures))
                    ExposureFramework.shared.doneAnalyzingKeys()
                    finish(.success(newExposures))
                }
            } // detectExposures
            print("detectExposures invoked")
        } catch {
            print("Unexpected error: \(error)")
        }
        return progress
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
        self.title = keyCount == 1 ? "a diagnositic key for \(userName) from GAEN Explorer" : "\(keyCount) diagnositic keys for \(userName) from GAEN Explorer"
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
