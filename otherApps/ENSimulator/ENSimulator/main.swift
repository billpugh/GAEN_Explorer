//
//  main.swift
//  ENSimulator
//
//  Created by Bill Pugh on 8/12/20.
//  Copyright © 2020 Bill Pugh. All rights reserved.
//

import Foundation

let attnFix = 10
let avgAttnAtOneMeter = 60

func randomDouble() -> Double {
    1.0 - Double(arc4random()) / 0xFFFF_FFFF
}

func randomNormal() -> Double {
    let u1 = sqrt(-2 * log(randomDouble()))
    let u2 = sin(2 * 3.14159265358979 * randomDouble())
    return u1 * u2
}

protocol AttenuationGenerator {
    func reset()
    func next() -> Double
}

class MyGenerator: AttenuationGenerator {
    let persistentDev = 3.0
    let alwaysDev = 1.5
    let chancePersistentChange = 0.1
    let avg: Double
    func newPersistent() -> Double {
        persistentDev * randomNormal()
    }

    var persistent1: Double
    var persistent2: Double
    init(avg: Double) {
        self.avg = avg
        persistent1 = 0.0
        persistent2 = 0.0
        reset()
    }

    func reset() {
        persistent1 = newPersistent()
        persistent2 = newPersistent()
    }

    func next() -> Double {
        if randomDouble() < chancePersistentChange {
            persistent1 = newPersistent()
        }
        if randomDouble() < chancePersistentChange {
            persistent2 = newPersistent()
        }
        return avg + alwaysDev * randomNormal() + persistent1 + persistent2
    }
}

class Measurements {
    static let maxAttnBoost = 40
    static let attnBoostCount = maxAttnBoost + 1
    static let maxScans = 15
    static let scanCap = 12
    static let maxWeight = 8 * maxScans

    static func capScan(_ s: Int) -> Int {
        min(s, scanCap)
    }

    var counts: [[[Int]]]
    // indices:  attnBoost, scans, weighted duration
    init() {
        counts = Array(repeating: Array(repeating: [Int](repeating: 0, count: Measurements.maxWeight + 1), count: Measurements.maxScans + 1), count: Measurements.attnBoostCount)
//        for _ in 0 ... Measurements.maxAttnBoost {
//            var a1: [[Int]] = []
//            for _ in 0 ... Measurements.maxScans {
//                a1.append([Int](repeating: 0, count: Measurements.maxWeight + 1))
//            }
//            counts.append(a1)
//        }
    }

    func saw(attnBoost: Int, scans: Int, weightedDuration: Int) {
        counts[min(attnBoost, counts.count - 1)][min(scans, Measurements.maxScans)][min(weightedDuration, Measurements.maxWeight)] += 1
    }
}

let minimumGeneratorAvg = 50 - attnFix
// We can model attenuations with an average anywhere from minimumGeneratorAvg ... (minimumGeneratorAvg + maxAttnBoost)

class Config {
    let threshold: [Int]
    let weight: [Double]
    // weigthedDuration[x] = an array of the weighted duration seen after x scans

    var weightSoFar: [[Int]] = []
    var scansSoFar: Int = 0
    var measurements = Measurements()
    func reset() {
        weightSoFar = Array(repeating: [Int](repeating: 0, count: threshold.count), count: Measurements.maxAttnBoost + 1)

        scansSoFar = 0
    }

    init(thresholds: [Int], weights: [Double]) {
        threshold = thresholds
        weight = weights
        reset()
    }

    func getWeightIndex(_ attn: Double) -> Int {
        for i in 0 ..< threshold.count {
            if attn <= Double(threshold[i]) {
                return i
            }
        }
        return threshold.count
    }

    func getWeight(_ attn: Double) -> Double {
        let index = getWeightIndex(attn)
        if index == threshold.count {
            return 0
        }
        return weight[index]
    }

    func getWeight(_ scans: [Int]) -> Int {
        var total = 0.0
        for i in 0 ..< scans.count {
            total += Double(scans[i]) * weight[i]
        }
        return Int((2.5 * total).rounded())
    }

    func see(attn: Double) {
        scansSoFar += 1

        for b in 0 ... Measurements.maxAttnBoost {
            let weightIndex = getWeightIndex(attn + Double(b))

            if weightIndex < threshold.count {
                weightSoFar[b][weightIndex] = Measurements.capScan(weightSoFar[b][weightIndex] + 1)
            }

            measurements.saw(attnBoost: b, scans: scansSoFar, weightedDuration: getWeight(weightSoFar[b]))
        }
    }
}

let iterations = 50000

// let c = Config(thresholds: [60-attnFix, 67-attnFix, 70-attnFix], weights: [2.0, 1.5, 1]) // 98.91
// let c = Config(thresholds: [58, 67, 75] , weights: [2.0, 1.5, 1]) // penalty 137.375
// let c = Config(thresholds: [58, 62, 70] , weights: [1.2, 1.0, 0.4]) // penalty 111
//let c = Config(thresholds: [55,67,75], weights: [1.75, 1.0, 0.33]) // mediumNet
//let c = Config(thresholds: [55,63,70], weights: [1.5, 1.0, 0.4]) // narrowNet
let c = Config(thresholds: [55,70,80], weights: [2, 1.0, 0.25]) // narrowNet

// let c = Config(thresholds: [55, 70, 80] , weights: [2.0, 1.0, 0.25])

print("Generating \(iterations) runs")

let gen = MyGenerator(avg: Double(minimumGeneratorAvg))
for _ in 1 ... iterations {
    c.reset()
    gen.reset()
    for _ in 1 ... 15 {
        c.see(attn: gen.next())
    }
}

print("Generated\n")

func percentDetected(scans: Int, threshold: Int, avgAttn: Int, weight: Double = 1.0) -> Double {
    var total = 0
    let adjustedThreshold = Int(Double(threshold) / weight)
    for d in adjustedThreshold ... Measurements.maxWeight {
        total = total + c.measurements.counts[avgAttn - minimumGeneratorAvg][scans][d]
    }
    return Double(100 * total) / Double(iterations)
}

func printAll() {
    for scans in [1, 6, 12] {
        print("Scans \(scans), minutes: \(scans * 5 / 2)")
        var cummulative = [Int](repeating: 0, count: Measurements.attnBoostCount)
        var seen = false
        for d in (1 ..< Measurements.maxWeight).reversed() {
            if c.measurements.counts[0][scans][d] > 0 {
                seen = true
            }
            if !seen {
                continue
            }
            print(String(format: "%2d", d * 5 / 2), terminator: " ")
            for boost in 0 ..< c.measurements.counts.count {
                let w = c.measurements.counts[boost][scans][d]
                cummulative[boost] += w
                let percent = String(format: "%4.1f", Double(100 * cummulative[boost]) / Double(iterations))
                print(percent, terminator: " ")
            }
            print()
        }
        print()
    }
}

struct Goal: CustomStringConvertible {
    let name: String
    let scans: Int
    let attn: Int
    let weight: Double
    let positive: Bool
    func penalty(threshold: Int, configurationChange: Int) -> (Double, Double) {
        let detected = percentDetected(scans: scans, threshold: threshold, avgAttn: attn - configurationChange)
        if positive {
            return (detected, (100 - detected) * weight)
        }
        return (detected, detected * weight)
    }

    var description: String {
        "  \(f3d(scans * 5 / 2)) min, \(f3d(attn)) dB, \(f3f1(meters(avgAttn: attn)))m, \(f3f1(positive ? weight : -weight))    \(name)"
    }
}

let shortScans = 4
let mediumScans = 6
let longScans = 12
let veryNearAttn = 50
let nearAttn = 55
let medAttn = 65
let farAttn = 70
let veryFarAttn = farAttn + 4

func printParameters() {
    print()
    print("parameters")
    print("target scans: \(mediumScans), \(5 * mediumScans / 2) minutes")
    print("long scans: \(longScans), \(5 * longScans / 2) minutes")

    print("very near attn : \(veryNearAttn) dB, \(f3f1(meters(avgAttn: veryNearAttn)))m")
    print("near attn : \(nearAttn) dB, \(f3f1(meters(avgAttn: nearAttn)))m")
    print("med attn : \(medAttn) dB, \(f3f1(meters(avgAttn: medAttn)))m")
    print("far attn : \(farAttn) dB, \(f3f1(meters(avgAttn: farAttn)))m")
    print("very far attn : \(veryFarAttn) dB, \(f3f1(meters(avgAttn: veryFarAttn)))m")
    print()
}

func f3d(_ i: Int) -> String {
    String(format: "%3d", i)
}

func fpercent(_ i: Double) -> String {
    String(format: "%7d", Int(i + 0.5))
}

func f3f1(_ f: Double) -> String {
    String(format: "%4.1f", f)
}

func analyzeThresholdHeader() {
    print("\n       long     med    long     med    short   long    long    ")
    print("thr    near    near     med     med   v near    far   v far    score")
}

let goals = [Goal(name: "Long near", scans: longScans, attn: nearAttn, weight: 3, positive: true),
             Goal(name: "med near", scans: mediumScans, attn: nearAttn, weight: 2, positive: true),
             Goal(name: "Long med", scans: longScans, attn: medAttn, weight: 1, positive: true),
             Goal(name: "med med", scans: mediumScans, attn: medAttn, weight: 0.5, positive: true),

             Goal(name: "short immd", scans: shortScans, attn: veryNearAttn, weight: 0.5, positive: false),
             Goal(name: "short near", scans: shortScans, attn: nearAttn, weight: 1, positive: false),

             Goal(name: "medium far", scans: mediumScans, attn: farAttn, weight: 1, positive: false),
             Goal(name: "long far", scans: longScans, attn: farAttn, weight: 0.75, positive: false),

             Goal(name: "medium vfar", scans: mediumScans, attn: veryFarAttn, weight: 2, positive: false),
             Goal(name: "Long vfar", scans: longScans, attn: veryFarAttn, weight: 1, positive: false)]

func analyzeThreshold(threshold: Int, configurationChange: Int) -> Double {
    print("\(f3d(threshold))", terminator: " ")
    var penalty = 0.0
    for goal in goals {
        let (detected, p) = goal.penalty(threshold: threshold, configurationChange: configurationChange)
        penalty += p
        print("\(fpercent(detected))", terminator: " ")
    }
    print("\(fpercent(penalty))")
    return penalty
}

func meters(avgAttn: Int) -> Double {
    pow(10.0, Double(avgAttn - (avgAttnAtOneMeter - attnFix)) / 20.0)
}

printParameters()
var betterThreshold: Int = 0
var betterScore: Double = 1_000_000
var betterConfigurationChange: Int = -1

for c in 0 ... 0 {
    print("Configuration change \(c)")
    analyzeThresholdHeader()
    for t in 1 ... 25 {
        let thisScore =
            analyzeThreshold(threshold: t, configurationChange: c)
        if thisScore < betterScore {
            betterScore = thisScore
            betterThreshold = t
            betterConfigurationChange = c
        }
    }
    print("Better threshold: \(betterThreshold) minutes, configuration change \(betterConfigurationChange), penalty \(betterScore)")
    print()
}

betterConfigurationChange = 0
betterThreshold = 15
print()
print()
print("Better threshold: \(betterThreshold) minutes, configuration change \(betterConfigurationChange)")
print("attn fix: \(attnFix)")
print()
printParameters()
print()

print("Thresholds \(c.threshold.map { $0 + betterConfigurationChange }), Weights \(c.weight), weighted attenuation duration \(betterThreshold)")
print()
print("Goals:")
print("                         avg")
print("    recall  duration    attn   dist weight   Description")
for g in goals {
    let attn = g.attn
    let scans = g.scans
    let p = percentDetected(scans: scans, threshold: betterThreshold, avgAttn: attn - betterConfigurationChange)
    print("  \(fpercent(p))% \(g)")
}

print()

print("Recall% table")
print("                     minutes")
print("   m Attn ", terminator: " ")
for scan in 3 ... 12 {
    print("   \(f3d(Int(Double(scan) * 2.5 + 0.5)))", terminator: "   ")
}

print()
for boost in 0 ..< Measurements.attnBoostCount {
    let attn = minimumGeneratorAvg + boost + betterConfigurationChange
    if attn < 45 {
        continue
    }
    if attn > veryFarAttn {
        break
    }
    let m = meters(avgAttn: attn)
    print("\(f3f1(m)) \(f3d(attn))", terminator: " ")
    for scan in 3 ... 12 {
        let p = percentDetected(scans: scan, threshold: betterThreshold, avgAttn: attn - betterConfigurationChange)
        print(" \(fpercent(p))", terminator: " ")
    }
    print()
}

print()
let infectiousnessWeight = 2.0
print("Infectiousness Weight \(infectiousnessWeight)")

print("Goals:")
print("                         avg")
print("    recall  duration    attn   dist weight   Description")
for g in goals {
    let attn = g.attn
    let scans = g.scans
    let p = percentDetected(scans: scans, threshold: betterThreshold, avgAttn: attn - betterConfigurationChange, weight: infectiousnessWeight)
    print("  \(fpercent(p))% \(g)")
}

print()

print("                     minutes")
print("   m Attn ", terminator: " ")
for scan in 3 ... 12 {
    print("   \(f3d(Int(Double(scan) * 2.5 + 0.5)))", terminator: "   ")
}

print()
for boost in 0 ..< Measurements.attnBoostCount {
    let attn = minimumGeneratorAvg + boost + betterConfigurationChange
    if attn < 45 {
        continue
    }
    if attn > veryFarAttn {
        break
    }
    let m = meters(avgAttn: attn)
    print("\(f3f1(m)) \(f3d(attn))", terminator: " ")
    for scan in 3 ... 12 {
        let p = percentDetected(scans: scan, threshold: betterThreshold, avgAttn: attn - betterConfigurationChange, weight: infectiousnessWeight)
        print(" \(fpercent(p))", terminator: " ")
    }
    print()
}

// printAll()
