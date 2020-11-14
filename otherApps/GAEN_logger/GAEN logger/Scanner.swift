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

class AttnWindow {
    static let maxAttn: Int = 89
    static let period: TimeInterval = 60
    static let minPerPeriod: Int = 10
    static let width: Int = 5
    static let minAttn: Int = 60
    var startedAt: Date = Date()
    var currentCount: Int = 0
    var periodsOccuped: Int {
        return periodsKnownOccuped + (currentCount >= AttnWindow.minPerPeriod ? 1 : 0)
    }
    var periodsKnownOccuped: Int = 0
    static func window(attn: Int)  -> Int {
        return max(0, (attn - AttnWindow.minAttn) / AttnWindow.width)
    }
    static func firstAttn(window: Int) -> Int {
        return window * AttnWindow.width + AttnWindow.minAttn
    }
    static func lastAttn(window: Int) -> Int {
        return firstAttn(window: window) + AttnWindow.width - 1
    }
    func count(_ now: Date) {
        let timeSinceLast = now.timeIntervalSince(startedAt)
        if (timeSinceLast > AttnWindow.period || currentCount == 0) {
            // new interval
            if currentCount >= AttnWindow.minPerPeriod {
                periodsKnownOccuped += 1
            }
            currentCount = 1
            startedAt = now
        } else {
            currentCount += 1
        }
    }
    
}
struct GAEN_device: Identifiable {
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
    var count = 0
    var allValues: [Int]
    var allPeriods: [Int] = []
    var minAttn: Int
    var maxAttn: Int
    var windows: [AttnWindow]
    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        minAttn = 100
        maxAttn = 0
        allValues = []
        var myWindows :  [AttnWindow] = []
        for _ in 0 ... AttnWindow.window(attn: AttnWindow.maxAttn)  {
            myWindows.append( AttnWindow() )
        }
        windows = myWindows
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
    
    func sample(_ a: [Double]) -> String {
        return sample( a.map { Int ($0)})
    }
    
    func sample(_ a: [Int]) -> String {
        Self.samplePositions.map { p in "\(a[a.count * p / 100], nf3)" }.joined(separator: ", ")
    }
    
    
    var minutesAt: [Int] {
        return windows.map { $0.periodsOccuped }
    }
    static var minutesAtHeader: String {
        return (0 ... AttnWindow.window(attn: AttnWindow.maxAttn)).map {"\(AttnWindow.lastAttn(window: $0), nf3)" }.joined()
        
    }
    static var minutesAtExportHeader: String {
        return (0 ... AttnWindow.window(attn: AttnWindow.maxAttn)).map {"\(AttnWindow.lastAttn(window: $0), nf3)" }.joined(separator: ",")
        
    }
    
    var minutesAtExport: String {
        return minutesAt.map { "\($0, nf3)" }.joined(separator: ",")
    }
    var minutesAtString: String {
        return minutesAt.map { "\($0, nf3)" }.joined()
    }
    
    var description: String {
        "\(id, nf3)  \(RSSI)   \(count, nf3)  \(packetsPerMinute, nf)     \((lastSeen - firstSeen)/1000, nf)  \(minutesAtString)"
    }
    
    //11:24:06 AM,     0,     3,        59,     42,  42,  42,  42,  42,  42,  42
    static let exportHeader : String = "    started,  mins, count, pckts/min,\(minutesAtExportHeader),   \(samplePositions.map{ "\($0, nf3)" }.joined(separator: ", "))"
    var export : String {
        let sorted = allValues.sorted()
        return "\(time), \(Int((lastSeen - firstSeen)/60000), nf), \(sorted.count,nf),       \(packetsPerMinute,nf3), \(minutesAtExport),   \(sample(sorted))"
    }
    
    
    var duration: Int {
        count == 1 ? 0 : Int((250 + lastSeen - firstSeen) / (count - 1))
    }
    
    var packetsPerMinute: Int {
        if count <= 1 {
            return 0
        }
        return count * 60000 / Int(lastSeen - firstSeen)
        
    }
    
    var RSSI: String {
        "\(minAttn, nf3) ..\(maxAttn, nf3)"
    }
    
    var period: String {
        "\(minPeriod, nf)..\(maxPeriod, nf)"
    }
    
    mutating func update(attn: Int) {
        
        let now = Self.timeStamp()
        let nowDate = Date()
        let thisPeriod = now - lastSeen
        if count > 0 && thisPeriod < 200 {
            return
        }
        if (attn <= AttnWindow.maxAttn) {
            for w in AttnWindow.window(attn: attn) ..< windows.count {
                windows[w].count(nowDate)
            }
        }
        
        allPeriods.append(thisPeriod)
        minAttn = min(minAttn, attn)
        maxAttn = max(maxAttn, attn)
        allValues.append(attn)
        lastDate = Date()
        if count == 0 {
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
    
    func export() -> [String]{
        var export = all.map { $0.export }
        export.insert(GAEN_device.exportHeader, at: 0)
        return export
        
    }
    func saw(didDiscover peripheral: CBPeripheral, attn: Int) {
        for i in 0 ..< all.count {
            if all[i].peripheral == peripheral {
                all[i].update(attn: attn)
                return
            }
        }
        
        var newDevice = GAEN_device(peripheral: peripheral)
        newDevice.update(attn: attn)
        all.append(newDevice)
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
        let attn = 3 - RSSI.intValue
        if (attn < 35) {
            print("saw attn of \(attn), skipping")
            return
        }
        LocalState.shared.saw(didDiscover: peripheral, attn: attn)
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
