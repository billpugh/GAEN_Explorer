//
//  main.swift
//  ENSimulator
//
//  Created by Bill Pugh on 8/12/20.
//  Copyright © 2020 Bill Pugh. All rights reserved.
//

import Foundation

func randomDouble() -> Double {
    while true {
        let r = arc4random()
        if r > 0 {
            return Double(r) / 0xFFFF_FFFF
        }
    }
}

func randomNormal() -> Double {
    let u1 = sqrt(-2 * log(randomDouble()))
    let u2 = sin(2 * 3.14159265358979 * randomDouble())
    return u1 * u2
}

func randomAttenuation(avg: Double) -> Double {
    let r = randomNormal()

    return avg + 7 * r
}


protocol AttenuationGenerator {
    func reset()
    func next() -> Double
}
    
class MyGenerator {
    let persistentDev = 3.0
    let alwaysDev = 1.5
    let chancePersistentChange = 0.1
    let avg : Double
    func newPersistent() -> Double {
        return persistentDev * randomNormal()
    }
    var persistent1 : Double
    var persistent2 : Double
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
        if (randomDouble() < chancePersistentChange) {
            persistent1 = newPersistent()
        }
        if (randomDouble() < chancePersistentChange) {
            persistent2 = newPersistent()
        }
        return avg + alwaysDev * randomNormal() + persistent1 + persistent2
    }
}


class Measurements {
   
   
    static let maxAttnBoost = 30
    static let attnBoostCount = maxAttnBoost+1
    static let maxScans = 15
    static let scanCap = 12
    static let maxWeight = 8 * maxScans

    static func capScan(_ s: Int) -> Int {
        min(s, scanCap)
    }

    var counts: [[[Int]]]
    // indices:  attnBoost, scans, weighted duration
    init() {
        counts = Array(repeating: Array(repeating: [Int](repeating: 0, count: Measurements.maxWeight + 1), count: Measurements.maxScans+1), count: Measurements.attnBoostCount)
//        for _ in 0 ... Measurements.maxAttnBoost {
//            var a1: [[Int]] = []
//            for _ in 0 ... Measurements.maxScans {
//                a1.append([Int](repeating: 0, count: Measurements.maxWeight + 1))
//            }
//            counts.append(a1)
//        }
    }

    func saw(attnBoost: Int, scans: Int, weightedDuration: Int) {
        counts[min(attnBoost, counts.count-1)][min(scans, Measurements.maxScans)][min(weightedDuration, Measurements.maxWeight)] += 1
    }
}
let generatorAvg = 50

class Config {
    let threshold: [Int]
    let weight: [Double]
    // weigthedDuration[x] = an array of the weighted duration seen after x scans

    var weightSoFar: [[Int]] = []
    var scansSoFar: Int = 0
    var measurements = Measurements()
    func reset() {
        weightSoFar = Array(repeating: [Int](repeating: 0, count:  threshold.count), count: Measurements.maxAttnBoost+1)
       
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
//let c = Config(thresholds: [54, 60, 66], weights: [1.4, 1, 0.65])
//let c = Config(thresholds: [56, 62, 68], weights: [2.0, 1.5, 1])
// let c = Config(thresholds: [57, 63, 69], weights: [2.0, 1.5, 1]) // score 89.28
//let c = Config(thresholds: [57, 63, 68], weights: [2.0, 1.5, 1]) // 87.6
//let c = Config(thresholds: [57, 63, 67], weights: [2.0, 1.5, 1]) // 83
//let c = Config(thresholds: [57, 63, 66], weights: [2.0, 1.5, 1]) // 81.85799999999998
//let c = Config(thresholds: [59, 65, 68], weights: [2.0, 1.5, 1]) // 80.392, 81.971
let c = Config(thresholds: [58, 65, 68], weights: [2.0, 1.5, 1]) // 80.392, 81.971

//let c = Config(thresholds: [55, 63, 66], weights: [1, 0.5, 0]) // 82


print("Generating \(iterations) runs")

let gen = MyGenerator(avg: Double(generatorAvg))
for _ in 1 ... iterations {
    c.reset()
    gen.reset()
    for _ in 1 ... 15 {
        c.see(attn: gen.next())
    }
}
print("Generated\n")


func percentDetected(scans: Int, threshold: Int, avgAttn: Int) -> Double {
    var total = 0
    for d in threshold ... Measurements.maxWeight {
        total = total + c.measurements.counts[avgAttn-generatorAvg][scans][d]
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



struct Goal {
    let name:String
    let scans: Int
    let attn: Int
    let weight: Double
    let positive: Bool
    func penalty(threshold: Int, configurationChange: Int) -> (Double, Double) {
        let detected = percentDetected(scans: scans, threshold: threshold, avgAttn: attn-configurationChange)
        if (positive) {
            return (detected, (100-detected) * weight)
        }
        return (detected, detected * weight)
    }
}


let shortScans = 3
let mediumScans = 6
let longScans = 12
let veryNearAttn = 55
let nearAttn = 60
let medAttn = 65
let farAttn = 70
let veryFarAttn = farAttn + 4
print("target scans: \(mediumScans), \(5*mediumScans/2) minutes")
print("long scans: \(longScans), \(5*longScans/2) minutes")


print("far attn boost: \(farAttn)")
print("very far attn boost: \(veryFarAttn)")

func f3d(_ i: Int) -> String {
    String(format: "%3d", i)
}

func fpercent(_ i: Double) -> String {
    String(format: "%7d", Int(i+0.5))
}

func analyzeThresholdHeader() {
    print("\n       long     med    long     med    short   long    long    ")
    print(  "thr    near    near     med     med   v near    far   v far    score")
}

let goals = [ Goal(name: "Long near", scans: longScans, attn: nearAttn, weight: 3, positive: true),
              Goal(name: "med near", scans: mediumScans, attn: nearAttn, weight: 2, positive: true),
              Goal(name: "Long near", scans: longScans, attn: medAttn, weight: 1, positive: true),
              Goal(name: "med near", scans: mediumScans, attn: medAttn, weight: 0.5, positive: true),
              Goal(name: "short immd", scans: shortScans, attn: veryNearAttn, weight: 1, positive: false),
              Goal(name: "long far", scans: longScans, attn: farAttn, weight: 1, positive: false),
              Goal(name: "Long vfar", scans: longScans, attn: veryFarAttn, weight: 2, positive: false)
]


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


var betterThreshold:Int = 0
var betterScore: Double = 1000000
var betterConfigurationChange: Int = -1

for c in -2 ... 2 {
    print("Configuration change \(c)")
    analyzeThresholdHeader()
for t in 1 ... 25 {
    let thisScore =
    analyzeThreshold(threshold: t, configurationChange: c)
    if (thisScore < betterScore) {
        betterScore = thisScore
        betterThreshold = t
        betterConfigurationChange = c
    }
}
    print("Better threshold: \(betterThreshold) minutes, configuration change \(betterConfigurationChange), penalty \(betterScore)")
    print()
}

print()
 betterThreshold  = 15
betterConfigurationChange = 0
print()
 print("Better threshold: \(betterThreshold) minutes, configuration change \(betterConfigurationChange)")

print()
print("Thresholds \(c.threshold.map { $0+betterConfigurationChange }), Weights \(c.weight)")
print("Attn ", terminator: " ")
for scan in 3...12 {
    print("   \(f3d(Int(Double(scan)*2.5+0.5)))", terminator: "   ")
}
print()
for boost in 0 ..< Measurements.attnBoostCount {
    let attn = generatorAvg+boost+betterConfigurationChange
    print("\(f3d(attn))", terminator: " ")
    for scan in 3...12 {
        let p =  percentDetected(scans: scan, threshold: betterThreshold, avgAttn: attn-betterConfigurationChange)
        print(" \(fpercent(p))",  terminator: " ")
    }
    print()
}
// printAll()
