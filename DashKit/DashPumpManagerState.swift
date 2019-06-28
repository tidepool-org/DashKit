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

    public var timeZone: TimeZone

    public var basalProgram: BasalProgram

    public var podActivatedAt: Date?

    public var reservoirLevel: ReservoirLevel?

    public var lastStatusDate: Date?

    public var suspended: Bool

    public var unfinalizedBolus: UnfinalizedDose?
    public var unfinalizedTempBasal: UnfinalizedDose?
    public var unfinalizedSuspend: UnfinalizedDose?
    public var unfinalizedResume: UnfinalizedDose?

    var finalizedDoses: [UnfinalizedDose]

    // Temporal state not persisted

    internal enum SuspendTransition {
        case suspending
        case resuming
    }

    internal var suspendTransition: SuspendTransition?

    internal enum BolusTransition {
        case initiating
        case canceling
    }

    internal var bolusTransition: BolusTransition?

    public init(timeZone: TimeZone, basalProgram: BasalProgram) {
        self.timeZone = timeZone
        self.basalProgram = basalProgram
        self.finalizedDoses = []
        self.suspended = false
    }


    public init?(rawValue: [String : Any]) {
        guard
            let _ = rawValue["version"] as? Int,
            let rawBasalProgram = rawValue["basalProgram"] as? BasalProgram.RawValue,
            let basalProgram = BasalProgram(rawValue: rawBasalProgram)
            else {
            return nil
        }

        self.basalProgram = basalProgram

        self.podActivatedAt = rawValue["podActivatedAt"] as? Date
        self.lastStatusDate = rawValue["lastStatusDate"] as? Date

        if let suspended = rawValue["suspended"] as? Bool {
            self.suspended = suspended
        } else {
            self.suspended = false
        }

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

        if let rawUnfinalizedBolus = rawValue["unfinalizedBolus"] as? UnfinalizedDose.RawValue,
            let unfinalizedBolus = UnfinalizedDose(rawValue: rawUnfinalizedBolus)
        {
            self.unfinalizedBolus = unfinalizedBolus
        } else {
            self.unfinalizedBolus = nil
        }

        if let rawUnfinalizedTempBasal = rawValue["unfinalizedTempBasal"] as? UnfinalizedDose.RawValue,
            let unfinalizedTempBasal = UnfinalizedDose(rawValue: rawUnfinalizedTempBasal)
        {
            self.unfinalizedTempBasal = unfinalizedTempBasal
        } else {
            self.unfinalizedTempBasal = nil
        }

        if let rawUnfinalizedSuspend = rawValue["unfinalizedSuspend"] as? UnfinalizedDose.RawValue,
            let unfinalizedSuspend = UnfinalizedDose(rawValue: rawUnfinalizedSuspend)
        {
            self.unfinalizedSuspend = unfinalizedSuspend
        } else {
            self.unfinalizedSuspend = nil
        }

        if let rawUnfinalizedResume = rawValue["unfinalizedResume"] as? UnfinalizedDose.RawValue,
            let unfinalizedResume = UnfinalizedDose(rawValue: rawUnfinalizedResume)
        {
            self.unfinalizedResume = unfinalizedResume
        } else {
            self.unfinalizedResume = nil
        }

        if let rawFinalizedDoses = rawValue["finalizedDoses"] as? [UnfinalizedDose.RawValue] {
            self.finalizedDoses = rawFinalizedDoses.compactMap( { UnfinalizedDose(rawValue: $0) } )
        } else {
            self.finalizedDoses = []
        }
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "version": DashPumpManagerState.version,
            "timeZone": timeZone.secondsFromGMT(),
            "finalizedDoses": finalizedDoses.map( { $0.rawValue }),
            "basalProgram": basalProgram.rawValue,
            "suspended": suspended,
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

        if let unfinalizedBolus = self.unfinalizedBolus {
            rawValue["unfinalizedBolus"] = unfinalizedBolus.rawValue
        }

        if let unfinalizedTempBasal = self.unfinalizedTempBasal {
            rawValue["unfinalizedTempBasal"] = unfinalizedTempBasal.rawValue
        }

        if let unfinalizedSuspend = self.unfinalizedSuspend {
            rawValue["unfinalizedSuspend"] = unfinalizedSuspend.rawValue
        }

        if let unfinalizedResume = self.unfinalizedResume {
            rawValue["unfinalizedResume"] = unfinalizedResume.rawValue
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
