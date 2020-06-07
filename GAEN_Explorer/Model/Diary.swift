//
//  Diary.swift
//  GAEN_Explorer
//
//  Created by Bill on 6/7/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import Foundation

enum DiaryKind: CustomStringConvertible {
    case startExperiment
    case keysShared
    case exposuresShared
    case keysReceived(from: String)
    case analysisPerformed(pass: Int)
    case scanningChanged(on: Bool)
    case memo(txt: String)
    case timedEvent(txt: String, started: Date)

    var description: String {
        switch self {
        case .startExperiment:
            return "Experiment started"
        case .keysShared:
            return "Keys shared"
        case .exposuresShared:
            return "Exposures shared"
        case let .keysReceived(from):
            return "Keys received from \(from) "
        case let .analysisPerformed(pass):
            return "Analysis pass \(pass) performed"
        case .scanningChanged(on: true):
            return "Scanning turned on"
        case .scanningChanged(on: false):
            return "Scanning turned off"
        case let .memo(txt):
            return "memo: \(txt)"
        case let .timedEvent(event, started):
            return "\(event) ended, started \(LocalStore.shared.timeFormatter.string(from: started))"
        }
    }

    var csv: String {
        switch self {
        case .startExperiment:
            return "Experiment started"
        case .keysShared:
            return "Keys shared"
        case .exposuresShared:
            return "Exposures shared"
        case let .keysReceived(from):
            return "Keys received from, \(from)"
        case let .analysisPerformed(pass):
            return "Analysis pass performed, \(pass)"
        case .scanningChanged(on: true):
            return "Scanning turned on"
        case .scanningChanged(on: false):
            return "Scanning turned off"
        case let .memo(txt):
            return "memo, \(txt)"
        case let .timedEvent(event, started):
            return "event, \(event),  \(LocalStore.shared.shortDateFormatter.string(from: started))"
        }
    }
}

struct DiaryEntry {
    let at: Date
    var time: String {
        LocalStore.shared.timeFormatter.string(from: at)
    }

    let kind: DiaryKind
    init(_ at: Date, _ kind: DiaryKind) {
        self.at = at
        self.kind = kind
    }

    func csv(user: String) -> String {
        "diary, \(user), \(kind.csv)"
    }

    static let testData: [DiaryEntry] = [
        DiaryEntry(hoursAgo(0, minutes: 25), .startExperiment),
        DiaryEntry(hoursAgo(0, minutes: 23), .memo(txt: "Started dinner")),
        DiaryEntry(hoursAgo(0, minutes: 5), .timedEvent(txt: "Dessert", started: hoursAgo(0, minutes: 10))),
        DiaryEntry(hoursAgo(0, minutes: 4), .keysShared),
        DiaryEntry(hoursAgo(0, minutes: 3), .keysReceived(from: "Bob")),
        DiaryEntry(hoursAgo(0, minutes: 3), .analysisPerformed(pass: 1)),
    ]
}
