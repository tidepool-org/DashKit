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

// Primarily used for testing
private struct DateGeneratorWrapper {
    let dateGenerator: () -> Date
}

extension DateGeneratorWrapper: Equatable {
    static func == (lhs: DateGeneratorWrapper, rhs: DateGeneratorWrapper) -> Bool {
        return true
    }
}

public struct DashPumpManagerState: RawRepresentable, Equatable {

    public typealias RawValue = PumpManager.RawStateValue

    public static let version = 1

    public var timeZone: TimeZone

    public var basalProgram: BasalProgram

    public var podActivatedAt: Date?

    public var reservoirLevel: ReservoirLevel?
    
    public var podTotalDelivery: Double?

    public var lastStatusDate: Date?
    
    public var isPodAlarming: Bool = false

    public var unfinalizedBolus: UnfinalizedDose?
    public var unfinalizedTempBasal: UnfinalizedDose?
    public var unfinalizedSuspend: UnfinalizedDose?
    public var unfinalizedResume: UnfinalizedDose?

    var finishedDoses: [UnfinalizedDose]

    public var suspendState: SuspendState

    public var isSuspended: Bool {
        if case .suspended = suspendState {
            return true
        }
        return false
    }
    
    public var isBolusing: Bool {
        if let transition = activeTransition, transition == .startingBolus {
            return true
        }
        if let bolus = unfinalizedBolus, !bolus.isFinished(at: dateGenerator()) {
            return true
        }
        return false
    }

    // Temporal state not persisted
    
    internal enum ActiveTransition: Equatable {
        case startingBolus
        case cancelingBolus
        case startingTempBasal
        case cancelingTempBasal
        case suspendingPump
        case resumingPump
    }
    
    internal var activeTransition: ActiveTransition?
    
    public var connectionState: ConnectionState?
    
    private let dateGeneratorWrapper: DateGeneratorWrapper
    private func dateGenerator() -> Date {
        return dateGeneratorWrapper.dateGenerator()
    }

    public init?(basalRateSchedule: BasalRateSchedule, dateGenerator: @escaping () -> Date = Date.init) {
        self.timeZone = basalRateSchedule.timeZone
        guard let basalProgram = BasalProgram(items: basalRateSchedule.items) else {
            return nil
        }
        self.basalProgram = basalProgram
        self.dateGeneratorWrapper = DateGeneratorWrapper(dateGenerator: dateGenerator)
        self.finishedDoses = []
        self.suspendState = .resumed(dateGenerator())
    }


    public init?(rawValue: RawValue) {
        guard
            let _ = rawValue["version"] as? Int,
            let rawBasalProgram = rawValue["basalProgram"] as? BasalProgram.RawValue,
            let basalProgram = BasalProgram(rawValue: rawBasalProgram),
            let rawSuspendState = rawValue["suspendState"] as? SuspendState.RawValue,
            let suspendState = SuspendState(rawValue: rawSuspendState)
            else {
            return nil
        }
        
        self.dateGeneratorWrapper = DateGeneratorWrapper(dateGenerator: Date.init)

        self.basalProgram = basalProgram
        self.suspendState = suspendState

        self.podActivatedAt = rawValue["podActivatedAt"] as? Date
        self.lastStatusDate = rawValue["lastStatusDate"] as? Date
        self.podTotalDelivery = rawValue["podTotalDelivery"] as? Double
        self.isPodAlarming = rawValue["isPodAlarming"] as? Bool ?? false

        if let rawReservoirLevel = rawValue["reservoirLevel"] as? ReservoirLevel.RawValue {
            self.reservoirLevel = ReservoirLevel(rawValue: rawReservoirLevel)
        }

        if let timeZoneSeconds = rawValue["timeZone"] as? Int,
            let timeZone = TimeZone(secondsFromGMT: timeZoneSeconds) {
            self.timeZone = timeZone
        } else {
            self.timeZone = TimeZone.currentFixed
        }

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

        if let rawFinishedDoses = rawValue["finishedDoses"] as? [UnfinalizedDose.RawValue] {
            self.finishedDoses = rawFinishedDoses.compactMap( { UnfinalizedDose(rawValue: $0) } )
        } else {
            self.finishedDoses = []
        }
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "version": DashPumpManagerState.version,
            "timeZone": timeZone.secondsFromGMT(),
            "finishedDoses": finishedDoses.map( { $0.rawValue }),
            "basalProgram": basalProgram.rawValue,
            "suspendState": suspendState.rawValue,
            "isPodAlarming": isPodAlarming,
        ]

        if let lastStatusDate = lastStatusDate {
            rawValue["lastStatusDate"] = lastStatusDate
        }

        if let reservoirLevel = reservoirLevel {
            rawValue["reservoirLevel"] = reservoirLevel.rawValue
        }
        
        if let podTotalDelivery = podTotalDelivery {
            rawValue["podTotalDelivery"] = podTotalDelivery
        }

        if let lastStatusDate = lastStatusDate {
            rawValue["lastStatusDate"] = lastStatusDate
        }

        if let podActivatedAt = podActivatedAt {
            rawValue["podActivatedAt"] = podActivatedAt
        }

        if let unfinalizedBolus = unfinalizedBolus {
            rawValue["unfinalizedBolus"] = unfinalizedBolus.rawValue
        }

        if let unfinalizedTempBasal = unfinalizedTempBasal {
            rawValue["unfinalizedTempBasal"] = unfinalizedTempBasal.rawValue
        }

        if let unfinalizedSuspend = unfinalizedSuspend {
            rawValue["unfinalizedSuspend"] = unfinalizedSuspend.rawValue
        }

        if let unfinalizedResume = unfinalizedResume {
            rawValue["unfinalizedResume"] = unfinalizedResume.rawValue
        }

        return rawValue
    }
    
    mutating func updateFromPodStatus(status: PodStatus) {
        lastStatusDate = dateGenerator()
        reservoirLevel = ReservoirLevel(rawValue: status.reservoirUnitsRemaining)
        podActivatedAt = status.expirationDate - .days(3)
        podTotalDelivery = status.delivered
    }
}

extension DashPumpManagerState: CustomDebugStringConvertible {
    public var debugDescription: String {
        return [
            "* podActivatedAt: \(String(describing: podActivatedAt))",
            "* timeZone: \(timeZone)",
            "* suspendState: \(suspendState)",
            "* basalProgram: \(basalProgram)",
            "* finishedDoses: \(finishedDoses)",
            "* unfinalizedBolus: \(String(describing: unfinalizedBolus))",
            "* unfinalizedTempBasal: \(String(describing: unfinalizedTempBasal))",
            "* unfinalizedSuspend: \(String(describing: unfinalizedSuspend))",
            "* unfinalizedResume: \(String(describing: unfinalizedResume))",
            "* reservoirLevel: \(String(describing: reservoirLevel))",
            "* lastStatusDate: \(String(describing: lastStatusDate))",
            ].joined(separator: "\n")
    }
}

public enum SuspendState: Equatable, RawRepresentable {
    public typealias RawValue = [String: Any]

    private enum SuspendStateType: Int {
        case suspend, resume
    }

    case suspended(Date)
    case resumed(Date)

    private var identifier: Int {
        switch self {
        case .suspended:
            return 1
        case .resumed:
            return 2
        }
    }

    public init?(rawValue: RawValue) {
        guard let rawSuspendStateType = rawValue["type"] as? SuspendStateType.RawValue,
            let date = rawValue["date"] as? Date else {
                return nil
        }
        switch SuspendStateType(rawValue: rawSuspendStateType) {
        case .suspend?:
            self = .suspended(date)
        case .resume?:
            self = .resumed(date)
        default:
            return nil
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .suspended(let date):
            return [
                "type": SuspendStateType.suspend.rawValue,
                "date": date
            ]
        case .resumed(let date):
            return [
                "type": SuspendStateType.resume.rawValue,
                "date": date
            ]
        }
    }
}
