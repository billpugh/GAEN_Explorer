//
//  SensorFusion.swift
//  GAEN Explorer
//
//  Created by Bill on 6/7/20.
//  Copyright © 2020 NinjaMonkeyCoders. All rights reserved.
//

import CoreMotion
import Foundation

func getTimeFormatter() -> DateFormatter {
    let timeFormatter = DateFormatter()

    timeFormatter.timeStyle = .long
    return timeFormatter
}

enum Activity: String {
    case off
    case faceup
    case facedown
    case stationary
    case walking
    case moving
    case unknown

    static func get(_ cmActivity: CMMotionActivity?, _ hMode: HorizontalMode, _ scanningOn: Bool) -> Activity {
        if !scanningOn {
            return .off
        }
        switch hMode {
        case .faceup:
            return .faceup
        case .facedown:
            return .facedown
        default:
            guard let cmA = cmActivity else { return .unknown }
            if cmA.stationary { return .stationary }
            if cmA.running || cmA.cycling || cmA.automotive { return .moving }
            return .unknown
        }
    }
}

enum SensorReading {
    case scanning(Bool)
    case motion(CMMotionActivity)
    case horizontal(HorizontalMode)
}

struct AccumulatingAngle {
    var count: Int = 0

    var x: Double = 0.0
    var y: Double = 0.0
    var lastAngle: Double

    init(_ count: Int = 0, _ x: Double = 0.0, _ y: Double = 0.0, last: Double = .nan) {
        self.count = count
        self.x = x
        self.y = y
        self.lastAngle = last
    }

    func add(_ radians: Double) -> AccumulatingAngle {
        AccumulatingAngle(count + 1, x + cos(radians), y + sin(radians), last: radians)
    }

    func add(degrees: Double) -> AccumulatingAngle {
        add(Double.pi * degrees / 180.0)
    }

    var average: Double {
        if count == 0 { return .nan }
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
        sqrt(x * x + y * y) / Double(count)
    }
}

struct SensorData {
    let at: Date
    var time: String {
        getTimeFormatter().string(from: at)
    }

    let sensor: SensorReading
}

struct FusedData: Hashable {
    let at: Date
    var time: String {
        getTimeFormatter().string(from: at)
    }

    let activity: Activity
}

struct SignificantActivity: Hashable {
    init(_ data: FusedData, seconds: Int) {
        self.at = data.at
        self.activity = data.activity
        self.duration = seconds
    }

    let at: Date
    var time: String {
        getTimeFormatter().string(from: at)
    }

    let activity: Activity
    let duration: Int
}

extension CMSensorDataList: Sequence {
    public typealias Iterator = NSFastEnumerationIterator
    public func makeIterator() -> NSFastEnumerationIterator {
        NSFastEnumerationIterator(self)
    }
}

enum HorizontalMode {
    static func get(_ a: CMAcceleration) -> HorizontalMode {
        let az = abs(a.z)
        guard a.x * a.x + a.y * a.y < 0.1, az < 1.05, az > 0.9 else {
            return .unknown
        }
        if a.z > 0 {
            return .facedown
        }
        return .faceup
    }

    case unknown
    case faceup
    case facedown
    case invalid
}

enum PhoneOrientation {
    case faceup
    case facedown
    case landscapeRight
    case landscapeLeft
    case portrait
    case portraintUpsidedown
    case unknown
}

struct HoritzontalState {
    let at: Date
    let status: HorizontalMode
}

struct MotionAnalysis {
    let activities: [SignificantActivity]
    let activityDurations: [Activity: Int]
    let roll: AccumulatingAngle
    let pitch: AccumulatingAngle
    let yaw: AccumulatingAngle
}

class SensorFusion {
    static let shared = SensorFusion()

    private let analyzeMotionQueue = DispatchQueue(label: "com.ninjamonkeycoders.gaen.analyzeMotion", attributes: .concurrent)

    let motionActivityManager = CMMotionActivityManager()
    let motionManager = CMMotionManager()

    let pedometer = CMPedometer()

    var sensorRecorder: CMSensorRecorder?

    lazy var motionQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Motion queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    func requestMotionPermission(block: @escaping () -> Void) {
        motionActivityManager.queryActivityStarting(from: Date(timeIntervalSinceNow: -500),
                                                    to: Date(),
                                                    to: motionQueue) { activities, _ in
            guard let activities = activities else { return }
            print("Got \(activities.count) activities")
            block()
        }
    }

    var motionPermission: CMAuthorizationStatus {
        CMMotionActivityManager.authorizationStatus()
    }

    func startMotionCapture() {
        motionManager.deviceMotionUpdateInterval = 1.0
        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical,
                                               to: motionQueue) { data, _ in
            // Make sure the data is valid before accessing it.
            if let validData = data {
                // Get the attitude relative to the magnetic north reference frame.
                self.roll = self.roll.add(validData.attitude.roll)
                self.pitch = self.pitch.add(validData.attitude.pitch)
                self.yaw = self.yaw.add(validData.attitude.yaw)
            }
        }
        startAccel()
    }

    func stopMotionCapture() {
        motionManager.stopDeviceMotionUpdates()
    }

    func startAccel() {
        if CMSensorRecorder.isAccelerometerRecordingAvailable() {
            print("accelerometerRecordingAvailable")
            sensorRecorder = CMSensorRecorder()
            print("startAccel")
            analyzeMotionQueue.async {
                self.sensorRecorder!.recordAccelerometer(forDuration: 2 * 60 * 60) // Record for 20 minutes
                print("started record accelerometer")
            }
        } else {
            print("accelerometerRecording not available")
        }
    }

    static let minimumNumberOfSecondsToRecord: TimeInterval = 5
    var roll = AccumulatingAngle()
    var pitch = AccumulatingAngle()
    var yaw = AccumulatingAngle()

    private func fuseMotionData(from: Date, to: Date,
                                _ sensorData: [SensorData],
                                _ motions: [CMMotionActivity],
                                _ results: (MotionAnalysis?) -> Void)
    {
        var motionData: [SensorData] = motions.map { motion in SensorData(at: motion.startDate, sensor: SensorReading.motion(motion)) }
        print("Have \(motionData.count) motion readings")
        motionData.append(contentsOf: sensorData)

        var accel: CMMotionActivity?
        var scanning = true
        var horizontalMode: HorizontalMode = .unknown
        var fusedData: [FusedData] = []

        var activityDurations: [Activity: Int] = [:]
        motionData.sorted { $0.at < $1.at }.forEach { sensorData in
            switch sensorData.sensor {
            case let .scanning(isOn):
                scanning = isOn
            case let .motion(cmmActivity):
                accel = cmmActivity
            case let .horizontal(hMode):
                horizontalMode = hMode
            }
            let newActivity = Activity.get(accel, horizontalMode, scanning)
            let fused = FusedData(at: sensorData.at, activity: newActivity)

            if fusedData.count == 0 {
                fusedData.append(fused)
            } else if newActivity != fusedData.last!.activity {
                if fusedData.last!.at.addingTimeInterval(SensorFusion.minimumNumberOfSecondsToRecord) > sensorData.at {
                    if fusedData.count - 2 >= 0, fusedData[fusedData.count - 2].activity == fused.activity {
                        fusedData.remove(at: fusedData.count - 1)
                    } else {
                        fusedData[fusedData.count - 1] = fused
                    }
                } else {
                    fusedData.append(fused)
                }
            }
        }
        print("Got \(fusedData.count) fused data items")

        let maxDuration = Int(to.timeIntervalSince(from) + 200)
        var prevData: FusedData?
        var significantActivities: [SignificantActivity] = []
        fusedData.forEach { fd in
            print("\(fd.time)  \(fd.activity)")
            if let prev = prevData {
                let oldDuration: Int = activityDurations[prev.activity] ?? 0
                let thisDuration = Int(fd.at.timeIntervalSince(prev.at >= from ? prev.at : from))
                if thisDuration > 90 {
                    significantActivities.append(SignificantActivity(prev, seconds: thisDuration))
                }
                let newDuration = oldDuration + thisDuration
                if thisDuration > maxDuration {
                    let msg = "Got duration of \(thisDuration) for \(prev.activity), started \(prev.time), ended \(fd.time))"
                    print(msg)
                    LocalStore.shared.addDiaryEntry(.debugging, msg)
                } else {
                    activityDurations[prev.activity] = newDuration
                    print("set time doing \(prev.activity) to \(newDuration)")
                }
            }
            prevData = fd
        }
        if let prev = prevData {
            let oldDuration: Int = activityDurations[prev.activity] ?? 0
            let thisDuration = Int(to.timeIntervalSince(prev.at >= from ? prev.at : from))
            if thisDuration > 90 {
                significantActivities.append(SignificantActivity(prev, seconds: thisDuration))
            }
            let newDuration = oldDuration + thisDuration
            if thisDuration > maxDuration {
                let msg = "Got duration of \(thisDuration) for \(prev.activity), started \(prev.time), ended at experiment end at \(timeFormatter.string(from: to)))"
                print(msg)
                LocalStore.shared.addDiaryEntry(.debugging, msg)
            } else {
                activityDurations[prev.activity] = newDuration
                print("set time doing \(prev.activity) to \(newDuration)")
            }
        }
        print("Got \(fusedData.count) fused data items")

        print("activity durations")
        for (key, value) in activityDurations {
            print("  \(key) \(Int(value))")
        }
        results(MotionAnalysis(activities: significantActivities, activityDurations: activityDurations, roll: roll, pitch: pitch, yaw: yaw))
    }

    static let secondsNeededToRecognizeHorizontal: TimeInterval = 20
    func getSensorData(from: Date, to: Date, results: @escaping (MotionAnalysis?) -> Void) {
        analyzeMotionQueue.async {
            if self.sensorRecorder != nil {
                print("sensor recorded present")
            }

            if let sensor = self.sensorRecorder,
               let data = sensor.accelerometerData(from: from, to: to)
            {
                print("Got accel")
                var horiztonalData: [SensorData] = []

                var oldHorizontal: HorizontalMode = .invalid
                var startedHorizontal: Date?

                for datum in data {
                    if let accdatum = datum as? CMRecordedAccelerometerData {
                        let horizontal = HorizontalMode.get(accdatum.acceleration)
                        if oldHorizontal != horizontal {
                            if horizontal == .unknown {
                                if let sh = startedHorizontal {
                                    if sh.addingTimeInterval(SensorFusion.secondsNeededToRecognizeHorizontal) < accdatum.startDate {
                                        horiztonalData.append(SensorData(at: sh, sensor: SensorReading.horizontal(oldHorizontal)))
                                        startedHorizontal = nil
                                        horiztonalData.append(SensorData(at: accdatum.startDate, sensor: SensorReading.horizontal(horizontal)))
                                    }
                                } else if horiztonalData.isEmpty {
                                    horiztonalData.append(SensorData(at: accdatum.startDate, sensor: SensorReading.horizontal(horizontal)))
                                }

                            } else {
                                // faceup or facedown
                                startedHorizontal = accdatum.startDate
                            }
                        }
                        oldHorizontal = horizontal
                    }
                }

                if let sh = startedHorizontal {
                    if sh.addingTimeInterval(SensorFusion.secondsNeededToRecognizeHorizontal) < Date() {
                        horiztonalData.append(SensorData(at: sh, sensor: SensorReading.horizontal(oldHorizontal)))
                        startedHorizontal = nil
                    }
                }

                print("Got \(horiztonalData.count) sensor data in horizontal history")

                self.motionActivityManager.queryActivityStarting(from: from,
                                                                 to: to,
                                                                 to: self.motionQueue) { activities, _ in
                    guard let a = activities else {
                        results(nil)
                        return
                    }
                    self.fuseMotionData(from: from, to: to, horiztonalData, a, results)
                }
            } else {
                print("No accelerometerData available")

                self.motionActivityManager.queryActivityStarting(from: from,
                                                                 to: to,
                                                                 to: self.motionQueue) { activities, _ in
                    guard let a = activities else {
                        results(nil)
                        return
                    }
                    let horiztonalData: [SensorData] = [SensorData(at: from, sensor: SensorReading.horizontal(.unknown))]
                    self.fuseMotionData(from: from, to: to, horiztonalData, a, results)
                }
            }
        }
    }
}
