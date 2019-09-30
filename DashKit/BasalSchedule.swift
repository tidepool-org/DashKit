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

extension BasalProgram {
    public init?(items: [RepeatingScheduleValue<Double>]) {
        var basalSegments = [BasalSegment]()

        let rates = items.map { $0.value }
        let startTimes = items.map { $0.startTime }
        var endTimes = startTimes.suffix(from: 1)
        endTimes.append(.hours(24))

        let segmentUnit = Pod.minimumBasalScheduleEntryDuration
        for (rate,(start,end)) in zip(rates,zip(startTimes,endTimes)) {
            let podRate = Int(round(rate * Pod.podSDKInsulinMultiplier))

            do {
                let segment = try BasalSegment(startTime: Int(round(start/segmentUnit)), endTime: Int(round(end/segmentUnit)), basalRate: podRate)
                basalSegments.append(segment)
            } catch {
                return nil
            }
        }

        do {
            try self.init(basalSegments: basalSegments)
        } catch {
            return nil
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

extension BasalSegment: Equatable {
    public static func == (lhs: BasalSegment, rhs: BasalSegment) -> Bool {
        return lhs.startTime == rhs.startTime &&
            lhs.endTime == rhs.endTime &&
            lhs.basalRate == rhs.basalRate
    }
}

extension BasalProgram: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard let entriesRaw = rawValue["basalSegments"] as? [BasalSegment.RawValue] else {
            return nil
        }

        do {
            try self.init(basalSegments: entriesRaw.compactMap { BasalSegment(rawValue: $0) })
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

extension BasalProgram: Equatable {
    public static func == (lhs: BasalProgram, rhs: BasalProgram) -> Bool {
        return zip(lhs.basalSegments, rhs.basalSegments).allSatisfy { $0.0 == $0.1 }
   }
}

