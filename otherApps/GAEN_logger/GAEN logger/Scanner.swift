//
//  Scanner.swift
//  GAEN logger
//
//  Created by Bill on 6/1/20.
//  Copyright © 2020 NinjaMonkeyCoders. All rights reserved.
//

import Foundation

import CoreBluetooth

let nf: NumberFormatter = {
    let nf = NumberFormatter()
    nf.formatWidth = 5
    return nf
}()

let nf3: NumberFormatter = {
    let nf = NumberFormatter()
    nf.formatWidth = 3
    return nf
}()

extension String.StringInterpolation {
    mutating func appendInterpolation(_ value: Int, _ formatter: NumberFormatter) {
        if let result = formatter.string(from: value as NSNumber) {
            appendLiteral(result)
        }
    }
}

struct GAEN_device: Identifiable, Comparable {
    static var nextId: Int = 0
    static func getNextId() -> Int {
        nextId += 1
        return nextId
    }

    let id: Int = GAEN_device.getNextId()

    static func < (lhs: GAEN_device, rhs: GAEN_device) -> Bool {
        switch (lhs.recent, rhs.recent) {
        case (true, false):
            return true
        case (false, true):
            return false
        case (false, false):
            return lhs.id > rhs.id
        case (true, true):
            return lhs.id < rhs.id
        }
    }

    static let timeFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    typealias intervalType = Int
    static func timeStamp() -> intervalType {
        Int(mach_continuous_time() / 1_000_000)
    }

    var time: String {
        Self.timeFormat.string(from: created)
    }

    var lastTime: String {
        Self.timeFormat.string(from: lastDate)
    }

    var analyzed = false
    let peripheral: CBPeripheral
    let created = Date()
    var lastDate = Date()
    let firstSeen = Self.timeStamp()
    var lastSeen = Self.timeStamp()
    var minPeriod: intervalType = 0
    var maxPeriod: intervalType = 0
    var count = 1
    var allValues: [Int]
    var allPeriods: [Int] = []
    var minRSSI: Int
    var maxRSSI: Int
    init(peripheral: CBPeripheral, RSSI: Int) {
        self.peripheral = peripheral
        minRSSI = RSSI
        maxRSSI = RSSI
        allValues = [RSSI]
    }

    var age: TimeInterval {
        Date().timeIntervalSince(lastDate)
    }

    var recent: Bool {
        age < 30
    }

    func median(_ a: ArraySlice<Int>) -> Double {
        // print("\(a.startIndex) ..< \(a.endIndex)")
        let sorted = a.sorted()
        let length = a.count
        // print("a.count \(a.count), sorted.count \(sorted.count)")
        var result: Double = 0.0
        if length % 2 == 0 {
            result = (Double(sorted[length / 2 - 1]) + Double(sorted[length / 2])) / 2.0
        } else {
            result = Double(sorted[length / 2])
        }
        // print("\(result) is median of \(sorted) and \(a)")
        return result
    }

    static let scanWidth = 11

    static let samplePositions = [5, 25, 40, 50, 60, 75, 95]

    func sample(_ a: [Any]) -> String {
        Self.samplePositions.map { p in "\(a[a.count * p / 100])" }.joined(separator: ", ")
    }

    var description: String {
        "\(id, nf3)  \(RSSI)  \(count, nf3)  \(period)  \(duration, nf)"
    }

    func dump() {
        let sorted = allValues.sorted()
        print ("\(time), \(Int((lastSeen - firstSeen)/60000)), \(sorted.count), \(sample(sorted))")
    }
    mutating func analyze() {
        analyzed = true
        if allValues.count < 100 {
            return
        }
        return
        // print("First 30 raw values \(allValues[0..<30].map { String($0) }.joined(separator: ", "))")
        let shuffled = allValues.shuffled()
        let scanValues = stride(from: 0, to: allValues.count - Self.scanWidth, by: 1).map { median(allValues[$0 ..< $0 + Self.scanWidth]) }.sorted()
        let shuffledMedians = stride(from: 0, to: allValues.count - Self.scanWidth, by: 1).map { median(shuffled[$0 ..< $0 + Self.scanWidth]) }.sorted()
        let sorted = allValues.sorted()
        print("A \(allValues.count),  \(sample(scanValues)),  \(sample(shuffledMedians)),  \(sample(sorted)),  \(sample(allPeriods.sorted()))")
    }

    var duration: Int {
        count == 1 ? 0 : Int((lastSeen - firstSeen) / (count - 1))
    }

    var RSSI: String {
        "\(minRSSI, nf3) ..\(maxRSSI, nf3)"
    }

    var period: String {
        "\(minPeriod, nf)..\(maxPeriod, nf)"
    }

    mutating func update(RSSI: Int) {
        let now = Self.timeStamp()
        let thisPeriod = now - lastSeen
        if thisPeriod < 200 {
            return
        }
        allPeriods.append(thisPeriod)
        minRSSI = min(minRSSI, RSSI)
        maxRSSI = max(maxRSSI, RSSI)
        allValues.append(RSSI)
        lastDate = Date()
        if count == 1 {
            minPeriod = thisPeriod
            maxPeriod = thisPeriod
        } else {
            minPeriod = min(minPeriod, thisPeriod)
            maxPeriod = max(maxPeriod, thisPeriod)
        }
        lastSeen = Self.timeStamp()
        count += 1
    }
}

class LocalState: ObservableObject {
    static var shared = LocalState()

    @Published
    var all: [GAEN_device] = []

    func dump() {
        for d in all {
            d.dump()
        }
    }
    func saw(didDiscover peripheral: CBPeripheral, rssi: Int) {
        for i in 0 ..< all.count {
            if all[i].peripheral == peripheral {
                all[i].update(RSSI: rssi)
                return
            }
        }
        for i in 0 ..< all.count {
            if !all[i].analyzed, all[i].age > 200 {
                all[i].analyze()
            }
        }
        all.append(GAEN_device(peripheral: peripheral, RSSI: rssi))
    }
}

class Scanner: NSObject, CBCentralManagerDelegate {
    static let shared = Scanner()
    // 0xFEED - TILE
    // 0xFD6F - GAEN
    // 0xF30D - test
    let GAENServiceCBUUID = CBUUID(string: "0xFD6F")
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Powered on")

            central.scanForPeripherals(withServices: [GAENServiceCBUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        }
    }

    override init() {
        print("init'd")
        central = CBCentralManager(delegate: nil, queue: nil)
        super.init()
        central.delegate = self
    }

    var central: CBCentralManager

    func hello() {}

    func centralManager(_: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        LocalState.shared.saw(didDiscover: peripheral, rssi: 3 - RSSI.intValue)
        if false { print("Saw packet, RSSI \(RSSI) ")
        if true {
            for (k, v) in advertisementData {
                print(" \(k): \(v)")
            }
        }
        print()
        print("-------")
        print()
        }
    }
}
