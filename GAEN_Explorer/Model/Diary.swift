//
//  Diary.swift
//  GAEN_Explorer
//
//  Created by Bill on 6/7/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import Foundation

enum DiaryKind: String, CustomStringConvertible, Codable {
    case startExperiment
    case endExperiment
    case keysShared
    case exposuresShared
    case keysReceived
    case analysisPerformed
    case scanningChanged
    case memo
    case activity
    case debugging

    var description: String {
        switch self {
        case .startExperiment:
            return "Experiment started"
        case .endExperiment:
            return "Experiment ended"

        case .keysShared:
            return "Keys shared"
        case .exposuresShared:
            return "Exposures shared"
        case .keysReceived:
            return "Keys received from"
        case .analysisPerformed:
            return "Analysis"
        case .scanningChanged:
            return "Scanning changed"
        case .memo:
            return "memo:"
        case .activity:
            return "activity:"
        case .debugging:
            return "debugging:"
        }
    }
}

struct DiaryEntry: Codable {
    let at: Date
    let kind: DiaryKind
    let text: String

    init(_ at: Date, _ kind: DiaryKind, _ text: String = "") {
        self.at = at
        self.kind = kind
        self.text = text
    }

    init(significantActivity: SignificantActivity) {
        self.at = significantActivity.at
        self.kind = .activity
        self.text = "\(significantActivity.activity.rawValue): \(significantActivity.duration)"
    }

    var time: String {
        timeFormatter.string(from: at)
    }

    func csv(user: String) -> String {
        "diary, \(user), \(kind.description), \(time), \(text)"
    }

    static let testData: [DiaryEntry] = [
        DiaryEntry(hoursAgo(0, minutes: 25), .startExperiment),
        DiaryEntry(hoursAgo(0, minutes: 23), .memo, "Started dinner"),
        DiaryEntry(hoursAgo(0, minutes: 25), .endExperiment),
        DiaryEntry(hoursAgo(0, minutes: 4), .keysShared),
        DiaryEntry(hoursAgo(0, minutes: 3), .keysReceived, "Bob"),
        DiaryEntry(hoursAgo(0, minutes: 3), .analysisPerformed, "pass 1"),
    ]
}
