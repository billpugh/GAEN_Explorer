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
    var lastUpdate: Date = Date()
    var count: Int = 0
    var samples: [Double] = [Double](repeating: 0.0, count: 11)
    var next: Int = 0
    var attenuation: Double = 100.0
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
        attenuation = samples.reduce(0.0,+) / Double(min(count, samples.count))
        ready = count >= samples.count
        lastAttenuation = attn
    }
}

class Scanner: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate {
    static var shared: Scanner = Scanner()

    @Published var scans: [String: ScanRecord] = [:]
    @Published var attenuation: [String: Double] = [:]
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

    let serviceCBUUID = CBUUID(string: "0xF30D")
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
        print("init'd")
        central = CBCentralManager(delegate: nil, queue: nil)
        peripheral = CBPeripheralManager(delegate: nil, queue: nil)

        formatter.dateFormat = "HH:mm:ss.SSSS"
        super.init()
        central.delegate = self
        peripheral.delegate = self

        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
                                               object: nil, queue: nil) { _ in
            if self.advertise {
                self.toggleAdvertising()
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
        print("Updating advertising \(peripheral.state.rawValue) \(advertise) \(saysAdvertising)")
    }

    var central: CBCentralManager
    var peripheral: CBPeripheralManager
    func status() {
        print("\(peripheral.isAdvertising) \(central.isScanning)")
    }

    func centralManager(_: CBCentralManager, didDiscover _: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let tx = advertisementData["kCBAdvDataTxPowerLevel"] as? NSNumber
        let attn = (tx?.doubleValue ?? 7.0) - RSSI.doubleValue

        let from = advertisementData["kCBAdvDataLocalName"] as? String ?? ""
        print("\(formatter.string(from: Date())) attenuation \(attn) from \(from)")
        if false {
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
        packets[from] = sr.count
        if (detailed) {
            DataPoint.log(from: from, sr: sr)
        }
    }
}
