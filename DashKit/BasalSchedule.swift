//
//  BasalSchedule.swift
//  DashKit
//
//  Created by Pete Schwamb on 5/9/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import PodSDK
import LoopKit


public struct BasalSchedule {

    let entries: [BasalScheduleEntry]

    init(entries: [BasalScheduleEntry]) {
        self.entries = entries
    }

    public init(rateSchedule: BasalRateSchedule) {
        var entries = [BasalScheduleEntry]()

        let rates = rateSchedule.items.map { $0.value }
        let startTimes = rateSchedule.items.map { $0.startTime }
        var endTimes = startTimes.suffix(from: 1)
        endTimes.append(.hours(24))

        let segmentUnit = Pod.minimumBasalScheduleEntryDuration
        for (rate,(start,end)) in zip(rates,zip(startTimes,endTimes)) {
            let podRate = Int(round(rate * 100))
            entries.append(BasalScheduleEntry(startTime: Int(round(start/segmentUnit)), endTime: Int(round(end/segmentUnit)), basalRate: podRate))
        }

        self.init(entries: entries)
    }
}

public struct BasalScheduleEntry {
    let startTime: Int
    let endTime: Int
    let basalRate: Int
}

extension BasalScheduleEntry: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard
            let basalRate = rawValue["basalRate"] as? Int,
            let startTime = rawValue["startTime"] as? Int,
            let endTime = rawValue["endTime"] as? Int
            else {
                return nil
        }
        self.init(startTime: startTime, endTime: endTime, basalRate: basalRate)
    }

    public var rawValue: RawValue {
        return [
            "basalRate": basalRate,
            "startTime": startTime,
            "endTime": endTime,
        ]
    }
}


extension BasalSchedule: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard let entriesRaw = rawValue["entries"] as? [BasalScheduleEntry.RawValue] else {
            return nil
        }

        self.init(entries: entriesRaw.compactMap { BasalScheduleEntry(rawValue: $0) })
    }

    public var rawValue: RawValue {
        return [
            "entries": entries.map { $0.rawValue }
        ]
    }
}

extension BasalScheduleEntry: Equatable {
    public static func == (lhs: BasalScheduleEntry, rhs: BasalScheduleEntry) -> Bool {
        return
            lhs.basalRate == rhs.basalRate &&
            lhs.startTime == lhs.startTime &&
            lhs.endTime   == rhs.endTime
    }
}

extension BasalSchedule: Equatable {
    public static func == (lhs: BasalSchedule, rhs: BasalSchedule) -> Bool {
        return zip(lhs.entries, rhs.entries).allSatisfy { $0.0 == $0.1 }
   }
}

extension BasalSegment {
    init(entry: BasalScheduleEntry) throws {
        try self.init(startTime: entry.startTime, endTime: entry.endTime, basalRate: entry.basalRate)
    }
}

extension BasalProgram {
    init(basalSchedule: BasalSchedule) {
        do {
            let segments = try basalSchedule.entries.map { try BasalSegment(entry: $0) }
            try self.init(basalSegments: segments)
        } catch {
            fatalError("Could not convert basal schedule \(basalSchedule) to BasalProgram: \(error)")
        }
    }
}

