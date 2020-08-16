//
//  main.swift
//  ENSimulator
//
//  Created by Bill Pugh on 8/12/20.
//  Copyright © 2020 Bill Pugh. All rights reserved.
//

import Foundation

func randomDouble() -> Double {
    while (true) {
        let r = arc4random()
        if r > 0 {
            return Double(r)/0xffffffff
        }
    }
    
}

func randomNormal() -> Double {
    let u1 = sqrt(-2 * log(randomDouble()))
    let u2 = sin(2*3.14159265358979*randomDouble())
    return u1*u2
}

func randomAttenuation(avg: Double) -> Double {
    let r = randomNormal()
    if r < 0 {
        return avg + 3*r
    }
    return avg + 4*r
}

class Measeurements {
    static let maxAttnBoost = 10
    static let maxScans = 15
    static let maxWeight = 8 * maxScans
    var counts: [[[Int]]]
    init() {
        counts = []
        for _ in 0...Measeurements.maxAttnBoost {
            var a1:[[Int]] = []
            for _ in 0...Measeurements.maxScans {
                a1.append([Int](repeating: 0, count: Measeurements.maxWeight+1))
            }
            counts.append(a1)
        }
    }
    func saw(attnBoost:Int,  scans: Int, weightedDuration: Int) {
        counts[min(attnBoost,Measeurements.maxAttnBoost)][min(scans,Measeurements.maxScans)][min(weightedDuration,Measeurements.maxWeight)] += 1
    }
}
class Config {
    let threshold: [Int]
    let weight: [Int]
    // weigthedDuration[x] = an array of the weighted duration seen after x scans
    
    var weightSoFar: [Int] = [Int](repeating: 0, count: Measeurements.maxAttnBoost+1 )
    var scansSoFar: Int = 0
    var measurements = Measeurements()
    func reset() {
        weightSoFar = [Int](repeating: 0, count: Measeurements.maxAttnBoost+1 )
        scansSoFar = 0
    }
    init(thresholds: [Int], weights: [Int] ) {
        self.threshold = thresholds
        self.weight = weights
    }
    func getWeight(_ attn: Double) -> Int {
        for i in 0..<threshold.count {
            if (attn <= Double(threshold[i])) {
                return weight[i]
            }
        }
        return 0
    }
    func see(attn: Double) {
        scansSoFar += 1
        
        for b in 0..<weightSoFar.count {
            let w = getWeight(attn+Double(b))
            weightSoFar[b] += w
            measurements.saw(attnBoost: b, scans: scansSoFar, weightedDuration: weightSoFar[b])
        }
    }
}

let c: Config = Config(thresholds: [55, 60, 65], weights: [4, 2, 1])
for _ in 1 ... 100_000 {
    c.reset()
    for _ in 1...12 {
        let attn = randomAttenuation(avg: 55)
        c.see(attn: attn)
    }
}

var cummulative:Int = 0
let m = c.measurements.counts[0][8]
for d in 1..<m.count {
    let w = m[d]
    if w > 0 {
        cummulative += w
        print("\(d) \(w) \(cummulative)")
    }
}

