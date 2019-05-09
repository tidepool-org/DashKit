//
//  BasalProgram.swift
//  DashKit
//
//  Created by Pete Schwamb on 5/9/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import PodSDK
import LoopKit

extension BasalProgram {
    public init(schedule: BasalRateSchedule) {
        var segments = [BasalSegment]()

        let rates = schedule.items.map { $0.value }
        let startTimes = schedule.items.map { $0.startTime }
        var endTimes = startTimes.suffix(from: 1)
        endTimes.append(.hours(24))

        do {
            let segmentUnit = Pod.minimumBasalScheduleEntryDuration
            for (rate,(start,end)) in zip(rates,zip(startTimes,endTimes)) {
                let podRate = Int(round(rate / Pod.pulseSize))
                segments.append(try BasalSegment(startTime: Int(round(start/segmentUnit)), endTime: Int(round(end/segmentUnit)), basalRate: podRate))
            }

            try self.init(basalSegments: segments)
        } catch let error {
            fatalError("Error constructing BasalProgram from \(schedule): \(error)")
        }
    }
}


extension BasalSegment: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard
            let basalRate = rawValue["basalRate"] as? Int,
            let startTime = rawValue["startTime"] as? Int,
            let endTime = rawValue["endTime"] as? Int
            else {
                return nil
        }
        do {
            try self.init(startTime: startTime, endTime: endTime, basalRate: basalRate)
        } catch {
            return nil
        }
    }

    public var rawValue: RawValue {
        return [
            "basalRate": basalRate,
            "startTime": startTime,
            "endTime": endTime,
        ]
    }
}


extension BasalProgram: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard let basalSegmentsRaw = rawValue["basalSegments"] as? [BasalSegment.RawValue] else {
            return nil
        }

        do {
            try self.init(basalSegments: basalSegmentsRaw.compactMap { BasalSegment(rawValue: $0) })
        } catch {
            return nil
        }
    }

    public var rawValue: RawValue {
        return [
            "basalSegments": basalSegments.map { $0.rawValue }
        ]
    }
}

extension BasalSegment: Equatable {
    public static func == (lhs: BasalSegment, rhs: BasalSegment) -> Bool {
        return
            lhs.basalRate == rhs.basalRate &&
            lhs.startTime == lhs.startTime &&
            lhs.endTime   == rhs.endTime
    }
}

extension BasalProgram: Equatable {
    public static func == (lhs: BasalProgram, rhs: BasalProgram) -> Bool {
        return zip(lhs.basalSegments, rhs.basalSegments).allSatisfy { $0.0 == $0.1 }
   }
}


