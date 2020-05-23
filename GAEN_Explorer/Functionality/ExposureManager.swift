/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 A class that manages a singleton ENManager object.
 */

import Combine
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

    let dateF = DateFormatter()
    let dateFr = DateFormatter()
    let dateTimeFr = DateFormatter()

    func resetManager() {
        manager = ENManager()
    }

    init() {
        print("ENManager init'd")
        var nsDictionary: NSDictionary?
        if let path = Bundle.main.path(forResource: "Test1", ofType: ".entitlements") {
            nsDictionary = NSDictionary(contentsOfFile: path)
            var value = nsDictionary!["com.apple.developer.exposure-notification-test"]
            print(value)
        }
        dateF.dateFormat = "yyyy/MM/dd HH:mm ZZZ"
        dateFr.timeStyle = .none
        dateFr.dateStyle = .short
        dateFr.doesRelativeDateFormatting = true
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
        self.title = keyCount == 1 ? "a diagnositic key for \(userName)" : "\(keyCount) diagnositic keys for \(userName)"
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
