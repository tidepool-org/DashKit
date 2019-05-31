//
//  DashPumpManagerState.swift
//  DashKit
//
//  Created by Pete Schwamb on 4/18/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import LoopKit
import PodSDK

public struct DashPumpManagerState: RawRepresentable, Equatable {

    public typealias RawValue = PumpManager.RawStateValue

    public static let version = 1

    public var hasActivePod = false

    public var timeZone: TimeZone

    public var basalSchedule: BasalSchedule

    public init(timeZone: TimeZone, basalSchedule: BasalSchedule) {
        self.timeZone = timeZone
        self.basalSchedule = basalSchedule
    }

    public var podActivatedAt: Date?

    public var reservoirLevel: ReservoirLevel?

    public var lastStatusDate: Date?

    public init?(rawValue: [String : Any]) {
        guard
            let _ = rawValue["version"] as? Int,
            let rawBasalSchedule = rawValue["basalSchedule"] as? BasalSchedule.RawValue,
            let basalSchedule = BasalSchedule(rawValue: rawBasalSchedule)
            else {
            return nil
        }

        self.basalSchedule = basalSchedule

        self.podActivatedAt = rawValue["podActivatedAt"] as? Date
        self.lastStatusDate = rawValue["lastStatusDate"] as? Date

        if let rawReservoirLevel = rawValue["reservoirLevel"] as? ReservoirLevel.RawValue {
            self.reservoirLevel = ReservoirLevel(rawValue: rawReservoirLevel)
        }

        let timeZone: TimeZone
        if let timeZoneSeconds = rawValue["timeZone"] as? Int,
            let tz = TimeZone(secondsFromGMT: timeZoneSeconds) {
            timeZone = tz
        } else {
            timeZone = TimeZone.currentFixed
        }
        self.timeZone = timeZone

    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "version": DashPumpManagerState.version,
            "timeZone": timeZone.secondsFromGMT(),
            "basalSchedule": basalSchedule.rawValue,
        ]

        if let lastStatusDate = lastStatusDate {
            rawValue["lastStatusDate"] = lastStatusDate
        }

        if let reservoirLevel = reservoirLevel {
            rawValue["reservoirLevel"] = reservoirLevel.rawValue
        }

        if let lastStatusDate = lastStatusDate {
            rawValue["lastStatusDate"] = lastStatusDate
        }

        if let podActivatedAt = podActivatedAt {
            rawValue["podActivatedAt"] = podActivatedAt
        }


        return rawValue
    }

}

extension DashPumpManagerState: CustomDebugStringConvertible {
    public var debugDescription: String {
        return [
            "* timeZone: \(timeZone)",
            ].joined(separator: "\n")
    }
}
