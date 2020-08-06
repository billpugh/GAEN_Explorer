//
//  ContentView.swift
//  TestOrientation
//
//  Created by Bill on 7/20/20.
//  Copyright © 2020 NinjaMonkeyCoders. All rights reserved.
//

import CoreLocation
import CoreMotion
import Foundation
import SwiftUI

import LinkPresentation

let dateFormater: DateFormatter = {
    var df = DateFormatter()
    df.dateFormat = "yyyyMMddHHmm"
    return df
}()

extension UIDeviceOrientation: CustomStringConvertible {
    public var description: String {
        switch self {
        case .portrait:
            return "portrait"
        case .portraitUpsideDown:
            return "portraitUD"
        case .landscapeLeft:
            return "landscapeL"
        case .landscapeRight:
            return "landscapeR"
        case .faceUp:
            return "faceUp"
        case .faceDown:
            return "faceDown"
        case .unknown:
            return "unknown"
        @unknown default:
            return "unknown"
        }
    }
}

class LocalStore: ObservableObject {
    static let shared = LocalStore()

    @Published
    var userName: String = UserDefaults.standard.string(forKey: "userName") ?? "" {
        didSet {
            UserDefaults.standard.set(userName, forKey: "userName")
        }
    }
}

var startDate: Date = Date()
struct DataPoint {
    static var lastDate: Date = Date()
    static var all: [DataPoint] = []
    static func log() {
        let now = Date()

        for (k, sr) in Scanner.shared.scans {
            if sr.ready {
                all.append(DataPoint(date: now, pitch: MotionInfo.shared.pitch.degrees, roll: MotionInfo.shared.roll.degrees, yaw: MotionInfo.shared.yaw.degrees, compass: MotionInfo.shared.compassHeading, computedOrientation: MotionInfo.shared.computedOrientation, deviceOrientation: MotionInfo.shared.deviceOrientation, from: k, attenuation: sr.attenuation, packets: sr.packets))
                sr.logged()
            }
        }
        lastDate = now
    }

    static func export() -> URL? {
        let csv = all.map { $0.csv() }.joined(separator: "\n")
        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first

        let fileName = "\(dateFormater.string(from: Date()))-\(LocalStore.shared.userName)-attn.csv"

        guard let path = documents?.appendingPathComponent(fileName) else {
            return nil
        }

        do {
            print(path)
            try csv.write(to: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }

    func csv() -> String {
        let dateFormater = DateFormatter()
        dateFormater.dateFormat = "yyyyMMddHHmmss"
        let s1 = dateFormater.string(from: date)
        let s2 = dateFormater.string(from: startDate)
        print("\(s1) \(s2)")
        let t = Int(date.timeIntervalSince(startDate).rounded())
        return "\(s1), \(t), \(compass), \(computedOrientation), \(deviceOrientation),  \(from), \(String(format: "%.3f", attenuation)), \(packets)"
    }

    let date: Date
    let pitch: Int
    let roll: Int
    let yaw: Int
    let compass: Int
    let computedOrientation: UIDeviceOrientation
    let deviceOrientation: UIDeviceOrientation
    let from: String
    let attenuation: Double
    let packets: Int
}

func m(_ old: Double, _ new: Double) -> Double {
    0.9 * old + 0.1 * new
}

struct AccumulatingAngle {
    var x: Double = 0.0
    var y: Double = 0.0
    var lastAngle: Double

    init(_ x: Double = 0.0, _ y: Double = 0.0, last: Double = .nan) {
        self.x = x
        self.y = y
        lastAngle = last
    }

    func add(_ radians: Double) -> AccumulatingAngle {
        AccumulatingAngle(m(x, cos(radians)), m(y, sin(radians)), last: radians)
    }

    func add(degrees: Double) -> AccumulatingAngle {
        add(Double.pi * degrees / 180.0)
    }

    var average: Double {
        if x == 0, y == 0 { return .nan }
        return atan2(y, x)
    }

    var degrees: Int {
        let v = average
        if v.isNaN { return 0 }
        return Int(180 * v / Double.pi)
    }

    var lastDegrees: Int {
        let v = lastAngle
        if v.isNaN { return 0 }
        return Int(180 * v / Double.pi)
    }

    var confidence: Double {
        sqrt(x * x + y * y)
    }

    var confidenceInt: Int {
        Int((100 * sqrt(x * x + y * y)).rounded())
    }
}

class MotionInfo: NSObject, ObservableObject, CLLocationManagerDelegate {
    static var shared: MotionInfo = MotionInfo()

    var motion = CMMotionManager()
    let locationManager: CLLocationManager = CLLocationManager()

    var timer: Timer?
    @Published var started: Bool = false
    @Published var pitch: AccumulatingAngle = AccumulatingAngle()
    @Published var roll: AccumulatingAngle = AccumulatingAngle()
    @Published var yaw: AccumulatingAngle = AccumulatingAngle()
    @Published var computedOrientation: UIDeviceOrientation = .unknown
    @Published var deviceOrientation: UIDeviceOrientation = .unknown
    @Published var compassHeading: Int = 0
    var orientation: UIDeviceOrientation {
        let maxAngle = 10
        let minConfident = 0.95
        if pitch.confidence < minConfident {
            return .unknown
        }

        if abs(90 - pitch.degrees) <= maxAngle, pitch.confidence >= minConfident {
            return .portrait
        }
        if abs((-90) - pitch.degrees) <= maxAngle, pitch.confidence >= minConfident {
            return .portraitUpsideDown
        }
        if abs(pitch.degrees) > maxAngle {
            return .unknown
        }
        if abs(90 - roll.degrees) <= maxAngle, pitch.confidence >= minConfident {
            return .landscapeRight
        }
        if abs((-90) - roll.degrees) <= maxAngle, pitch.confidence >= minConfident {
            return .landscapeLeft
        }
        if abs(roll.degrees) < maxAngle {
            return .faceUp
        }
        if abs(180 - roll.degrees) < maxAngle {
            return .faceDown
        }
        return .unknown
    }

    func adjust(_ radians: Double) -> Int {
        Int(180 * radians / 3.1415926)
    }

    func stopMotion() {
        timer?.invalidate()
        timer = nil
        started = false
    }

    private func orientationAdjustment() -> Double {
        let isFaceDown: Bool = {
            switch UIDevice.current.orientation {
            case .faceDown: return true
            default: return false
            }
        }()

        let adjAngle: Double = {
            switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft: return 90
            case .landscapeRight: return -90
            case .portrait, .unknown: return 0
            case .portraitUpsideDown: return isFaceDown ? 180 : -180
            }
        }()

        return adjAngle
    }

    func locationManager(_: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // print("Got heading \(newHeading.trueHeading)")
        var heading: Double = newHeading.trueHeading
        if UIDevice.current.orientation != .faceDown {
            heading = -heading
        }
        let cHeading = Int(orientationAdjustment() + heading)
        compassHeading = (cHeading + 720) % 360
    }

    override init() {
        super.init()

        if motion.isDeviceMotionAvailable {
            locationManager.delegate = self
            locationManager.requestWhenInUseAuthorization()
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingHeading()
            locationManager.startUpdatingLocation()
            print("starting motion")
            pitch = AccumulatingAngle()
            roll = AccumulatingAngle()
            yaw = AccumulatingAngle()
            motion.deviceMotionUpdateInterval = 1.0 / 20
            motion.showsDeviceMovementDisplay = true
            motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)

            // Configure a timer to fetch the motion data.
            timer = Timer(fire: Date(), interval: 1.0 / 10, repeats: true,
                          block: { _ in
                              if let data = self.motion.deviceMotion {
                                  // Get the attitude relative to the magnetic north reference frame.
                                  self.pitch = self.pitch.add(data.attitude.pitch)
                                  self.roll = self.roll.add(data.attitude.roll)
                                  self.yaw = self.yaw.add(data.attitude.yaw)
                                  // print("Got data \(self.pitch.degrees)  \(self.roll.degrees)  \(self.yaw.degrees) \(self.orientation)")
                                  self.computedOrientation = self.orientation
                                  self.deviceOrientation = UIDevice.current.orientation
                                  // Use the motion data in your app.
                              }
            })

            // Add the timer to the current run loop.
            RunLoop.current.add(timer!, forMode: RunLoop.Mode.default)
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?
    @Binding var isPresented: Bool

    func makeUIViewController(context _: UIViewControllerRepresentableContext<ActivityView>) -> UIActivityViewController {
        let result = UIActivityViewController(activityItems: activityItems,
                                              applicationActivities: applicationActivities)
        result.excludedActivityTypes = [UIActivity.ActivityType.addToReadingList,
                                        UIActivity.ActivityType.assignToContact,
                                        UIActivity.ActivityType.copyToPasteboard,
                                        UIActivity.ActivityType.markupAsPDF,
                                        UIActivity.ActivityType.openInIBooks,
                                        UIActivity.ActivityType.postToFacebook,
                                        UIActivity.ActivityType.postToFlickr,
                                        UIActivity.ActivityType.postToTencentWeibo,
                                        UIActivity.ActivityType.postToTwitter,
                                        UIActivity.ActivityType.postToVimeo,
                                        UIActivity.ActivityType.postToWeibo,
                                        UIActivity.ActivityType.print,
                                        UIActivity.ActivityType.saveToCameraRoll,
                                        UIActivity.ActivityType(rawValue: "com.apple.reminders.sharingextension"),
                                        UIActivity.ActivityType(rawValue: "com.apple.mobilenotes.SharingExtension")]
        result.completionWithItemsHandler = { (activityType: UIActivity.ActivityType?, completed:
            Bool, _: [Any]?, error: Error?) in
        print("activity: \(String(describing: activityType))")

        if completed {
            print("share completed")
            self.isPresented = false
            return
        } else {
            print("cancel")
        }
        if let shareError = error {
            print("error while sharing: \(shareError.localizedDescription)")
        }
        }
        return result
    }

    func updateUIViewController(_: UIActivityViewController,
                                context _: UIViewControllerRepresentableContext<ActivityView>) {}
}

class ExportItem: NSObject, UIActivityItemSource {
    let url: URL?
    let title: String
    init(url: URL?, title: String) {
        self.url = url
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_: UIActivityViewController) -> Any {
        "Data from attenuation logger"
    }

    func activityViewController(_: UIActivityViewController, itemForActivityType _: UIActivity.ActivityType?) -> Any? {
        url ?? title
    }

    func activityViewController(_: UIActivityViewController,
                                subjectForActivityType _: UIActivity.ActivityType?) -> String {
        title
    }

    func activityViewControllerLinkMetadata(_: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = url

        metadata.title = title
        return metadata
    }
}

struct ContentView: View {
    @ObservedObject var localStore = LocalStore.shared
    @ObservedObject var mInfo = MotionInfo.shared
    @ObservedObject var scanner = Scanner.shared
    @State private var exporting = false
    @State var exportURL: URL? = nil

    var body: some View {
        VStack(spacing: 10) {
            Group {
                HStack {
                    Text("User name: ")
                    TextField("User name", text: self.$localStore.userName)
                }
                HStack(spacing: 10) {
                    Text("\(dateFormater.string(from: startDate))")
                    Button(action: { DataPoint.all = []
                        startDate = Date()
                        Scanner.shared.scans = [:]
                        Scanner.shared.attenuation = [:]
                        Scanner.shared.packets = [:]
                }) { Text("reset") }
                }
                Toggle(isOn: self.$scanner.logging) {
                    Text("Logging")
                }.padding()
                Toggle(isOn: self.$scanner.detailed) {
                    Text("Detailed")
                }.padding()
                Toggle(isOn: self.$scanner.advertise) {
                    Text("Advertising")
                }.padding()

                if false {
                    Text("Pitch \(mInfo.pitch.degrees)  \(mInfo.pitch.lastDegrees) \(mInfo.pitch.confidenceInt)")
                    Text("Roll \(mInfo.roll.degrees) \(mInfo.roll.lastDegrees)  \(mInfo.roll.confidenceInt)")
                    Text("Yaw \(mInfo.yaw.degrees) \(mInfo.yaw.lastDegrees) \(mInfo.yaw.confidenceInt)")
                }
                Text("Compass \(mInfo.compassHeading) ")
                
                // Text("Orientation \(String(describing: mInfo.computedOrientation))  \(String(describing: mInfo.deviceOrientation))")
            }
            ForEach(scanner.attenuation.sorted(by: >), id: \.key) { key, attn in
                Text("\(key) \(String(format: "%.1f", attn)) \(self.scanner.packets[key]!)")
            }

            Text("Advertising \(scanner.advertise ? "Y" : "N") \(scanner.saysAdvertising ? "Y" : "N")")
            Text("Data \(DataPoint.all.count)")
            Button(action: { self.exportURL = DataPoint.export()
                if self.exportURL != nil {
                    self.exporting = true
                }
            }) { Text("Export") }
        }.font(.headline).onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }.onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false

        }.sheet(isPresented: self.$exporting, onDismiss: { print("share sheet dismissed") },
                content: {
                    ActivityView(activityItems: [
                        ExportItem(url: self.exportURL,
                                   title: "Export from attenuation logging"),
                    ] as [Any], applicationActivities: nil, isPresented: self.$exporting)
        })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
