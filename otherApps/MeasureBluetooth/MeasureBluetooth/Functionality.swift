//
//  Functionality.swift
//  TestOrientation
//
//  Created by Bill on 7/29/20.
//  Copyright © 2020 NinjaMonkeyCoders. All rights reserved.
//

import CoreBluetooth
import Foundation
import SwiftUI

class ScanRecord {
    var packets: Int = 0
    var lastUpdate = Date()
    var count: Int = 0
    var samples = [Double](repeating: 0.0, count: 11)
    var next: Int = 0
    var attenuation: Double = 100.0
    var attenuationP: Double = 100.0
    var lastAttenuation: Double = 100.0
    var attenuationString: String {
        String(format: "%.1f", attenuation)
    }

    var ready: Bool = false

    func logged() {
        ready = false
    }

    func reset() {
        count = 0
        samples = [Double](repeating: 0.0, count: 11)
        next = 0
        ready = false
    }

    func average(_ values: [Double]) -> Double {
        return values.reduce(0.0,+) / Double(values.count)
    }
    func add(_ attn: Double) {
        packets += 1
        let now = Date()
        if now.timeIntervalSince(lastUpdate) > 4 {
            reset()
            print("resetting scan record")
        }
        lastUpdate = now
        count += 1
        samples[next] = attn
        next = (next + 1) % samples.count
        let validSamples = samples.filter {$0 != 0.0}
        
        attenuation = average(validSamples)
        let powers =  validSamples.map { pow(10.0, $0 / -10.0 )}
        attenuationP = -10 * log10(average(powers))
        ready = count >= samples.count
        lastAttenuation = attn
    }
}

class Scanner: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate {
    static var shared = Scanner()

    @Published var scans: [String: ScanRecord] = [:]
    @Published var attenuation: [String: Double] = [:]
    @Published var lastScan: [String: Date] = [:]
    @Published var packets: [String: Int] = [:]

    @Published var detailed: Bool = false
    @Published var logging: Bool = false
    // static let shared = Scanner()
    // 0xFEED - TILE
    // 0xFD6F - GAEN

    @Published
    var saysAdvertising: Bool = false

    @Published
    var advertise: Bool = false {
        didSet {
            advertisingChanged()
        }
    }

    var peripheralState: CBManagerState = .unknown
    func toggleAdvertising() {
        advertise = !advertise
    }

    func advertisingChanged() {
        if peripheralState == .poweredOn {
            if advertise {
                print("Starting advertising")
                peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceCBUUID],
                                             CBAdvertisementDataLocalNameKey: LocalStore.shared.userName])
            } else {
                print("stopping advertising")
                peripheral.stopAdvertising()
            }
        }
        saysAdvertising = peripheral.isAdvertising
        print("toggle advertising \(advertise) \(peripheralState.rawValue)")
    }

    let serviceCBUUID = CBUUID(string: "0xF30D") // CBUUID(string: "0x180D") //
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("central Powered on")

            central.scanForPeripherals(withServices: [serviceCBUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        }
    }

    func peripheralManagerDidStartAdvertising(_: CBPeripheralManager, error _: Error?) {
        print("peripheralManagerDidStartAdvertising")
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        peripheralState = peripheral.state
        print("peripheralManagerDidUpdateState \(peripheralState)")
        if peripheralState == .poweredOn {
            print("peripheral Powered on")

            if advertise {
                print("Starting advertising")
                peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceCBUUID],
                                             CBAdvertisementDataLocalNameKey: LocalStore.shared.userName])
            }
        }
    }

    let formatter = DateFormatter()
    var timer: Timer?
    var counter: Int = 0
    override init() {
        print("initializing scanner")
        central = CBCentralManager(delegate: nil, queue: nil)
        peripheral = CBPeripheralManager(delegate: nil, queue: nil)

        formatter.dateFormat = "HH:mm:ss.SSSS"
        super.init()
        central.delegate = self
        peripheral.delegate = self

        if false {
            NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
                                                   object: nil, queue: nil) { _ in
                if self.advertise {
                    self.toggleAdvertising()
                }
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.counter += 1
            if self.counter % 5 == 0 {
                self.updateScanner()
            }
            if self.logging {
                DataPoint.log()
            }
        }
    }

    func updateScanner() {
        saysAdvertising = peripheral.isAdvertising
        //print("Updating advertising \(peripheral.state.rawValue) \(advertise) \(saysAdvertising)")
    }

    var central: CBCentralManager
    var peripheral: CBPeripheralManager
    func status() {
        print("\(peripheral.isAdvertising) \(central.isScanning)")
    }

    func centralManager(_: CBCentralManager, didDiscover _: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let attn = -RSSI.doubleValue
        
        if attn < 20 || attn > 110 {
            return
        }

        let from = advertisementData["kCBAdvDataLocalName"] as? String ?? ""
        if false {
            print("\(formatter.string(from: Date())) attenuation \(attn) from \(from)")

            for (k, v) in advertisementData {
                print(" \(k): \(v)")
            }
        }
        if scans[from] == nil {
            scans[from] = ScanRecord()
        }
        let sr = scans[from]!
        sr.add(attn)
        attenuation[from] = sr.attenuation
        lastScan[from] = Date()
        packets[from] = sr.count
        if detailed {
            DataPoint.log(from: from, sr: sr)
        }
    }
}
