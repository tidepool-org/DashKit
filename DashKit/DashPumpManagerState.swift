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
    
    public var scheduledExpirationReminderOffset: TimeInterval?
    
    public var defaultExpirationReminderOffset = Pod.defaultExpirationReminderOffset

    public var lowReservoirReminderValue: Double
    
    public var podAttachmentConfirmed: Bool

    public var alarmCode: AlarmCode?
    
    public var lastPodCommState: PodCommState {
        didSet {
            lastPodCommDate = dateGenerator()
        }
    }
    public private(set) var lastPodCommDate: Date?
    
    public var unfinalizedBolus: UnfinalizedDose?
    public var unfinalizedTempBasal: UnfinalizedDose?

    var finishedDoses: [UnfinalizedDose]
    
    public var suspendState: SuspendState?
    
    public var pendingCommand: PendingCommand?

    public var confidenceRemindersEnabled: Bool = false
    
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
    
    public var activeAlerts: Set<PumpManagerAlert>
    
    public var alertsWithPendingAcknowledgment: Set<PumpManagerAlert>

    public var acknowledgedTimeOffsetAlert: Bool
    
    // Indicates that the user has completed initial configuration
    // which means they have configured any parameters, but may not have paired a pod yet.
    public var initialConfigurationCompleted: Bool = false
    
    // Indicates that the user has completed onboarding
    public var onboardingCompleted: Bool = false

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

    public init?(basalRateSchedule: BasalRateSchedule, lastPodCommState: PodCommState, dateGenerator: @escaping () -> Date = Date.init) {
        self.timeZone = basalRateSchedule.timeZone
        guard let basalProgram = BasalProgram(items: basalRateSchedule.items) else {
            return nil
        }
        self.basalProgram = basalProgram
        self.dateGeneratorWrapper = DateGeneratorWrapper(dateGenerator: dateGenerator)
        self.finishedDoses = []
        self.suspendState = .resumed(dateGenerator())
        self.activeAlerts = []
        self.alertsWithPendingAcknowledgment = []
        self.lastPodCommState = lastPodCommState
        self.lastPodCommDate = dateGenerator()
        self.lowReservoirReminderValue = Pod.defaultLowReservoirReminder
        self.podAttachmentConfirmed = false
        self.acknowledgedTimeOffsetAlert = false
    }


    public init?(rawValue: RawValue) {
        guard
            let _ = rawValue["version"] as? Int,
            let rawBasalProgram = rawValue["basalProgram"] as? BasalProgram.RawValue,
            let basalProgram = BasalProgram(rawValue: rawBasalProgram)
        else {
            return nil
        }
        
        self.dateGeneratorWrapper = DateGeneratorWrapper(dateGenerator: Date.init)
        
        self.basalProgram = basalProgram
        
        self.podActivatedAt = rawValue["podActivatedAt"] as? Date
        self.lastStatusDate = rawValue["lastStatusDate"] as? Date
        self.podTotalDelivery = rawValue["podTotalDelivery"] as? Double
        
        if let rawSuspendState = rawValue["suspendState"] as? SuspendState.RawValue {
            self.suspendState = SuspendState(rawValue: rawSuspendState)
        }
        
        if let rawAlarmCode = rawValue["alarmCode"] as? AlarmCode.RawValue {
            self.alarmCode = AlarmCode(rawValue: rawAlarmCode)
        }

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

        if let rawFinishedDoses = rawValue["finishedDoses"] as? [UnfinalizedDose.RawValue] {
            self.finishedDoses = rawFinishedDoses.compactMap( { UnfinalizedDose(rawValue: $0) } )
        } else {
            self.finishedDoses = []
        }
        
        self.activeAlerts = []
        if let rawActiveAlerts = rawValue["activeAlerts"] as? [PumpManagerAlert.RawValue] {
            for rawAlert in rawActiveAlerts {
                if let alert = PumpManagerAlert(rawValue: rawAlert) {
                    self.activeAlerts.insert(alert)
                }
            }
        }

        self.alertsWithPendingAcknowledgment = []
        if let rawAlerts = rawValue["alertsWithPendingAcknowledgment"] as? [PumpManagerAlert.RawValue] {
            for rawAlert in rawAlerts {
                if let alert = PumpManagerAlert(rawValue: rawAlert) {
                    self.alertsWithPendingAcknowledgment.insert(alert)
                }
            }
        }

        self.acknowledgedTimeOffsetAlert = rawValue["acknowledgedTimeOffsetAlert"] as? Bool ?? false
        
        if let rawPendingCommand = rawValue["pendingCommand"] as? PendingCommand.RawValue {
            self.pendingCommand = PendingCommand(rawValue: rawPendingCommand)
        } else {
            self.pendingCommand = nil
        }
        
        if let rawLastPodCommState = rawValue["lastPodCommState"] as? Data,
           let lastPodCommState = try? JSONDecoder().decode(PodCommState.self, from: rawLastPodCommState)
        {
            self.lastPodCommState = lastPodCommState
        } else {
            self.lastPodCommState = .noPod
        }

        self.lastPodCommDate = rawValue["lastPodCommDate"] as? Date
        
        self.scheduledExpirationReminderOffset = rawValue["scheduledExpirationReminderOffset"] as? TimeInterval
        
        self.defaultExpirationReminderOffset = rawValue["defaultExpirationReminderOffset"] as? TimeInterval ?? Pod.defaultExpirationReminderOffset
        
        self.lowReservoirReminderValue = rawValue["lowReservoirReminderValue"] as? Double ?? Pod.defaultLowReservoirReminder

        self.podAttachmentConfirmed = rawValue["podAttachmentConfirmed"] as? Bool ?? false

        self.confidenceRemindersEnabled = rawValue["confidenceRemindersEnabled"] as? Bool ?? false

        self.initialConfigurationCompleted = rawValue["initialConfigurationCompleted"] as? Bool ?? true

        self.onboardingCompleted = rawValue["onboardingCompleted"] as? Bool ?? true
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "version": DashPumpManagerState.version,
            "timeZone": timeZone.secondsFromGMT(),
            "finishedDoses": finishedDoses.map( { $0.rawValue }),
            "basalProgram": basalProgram.rawValue,
            "activeAlerts": activeAlerts.map { $0.rawValue },
            "alertsWithPendingAcknowledgment": alertsWithPendingAcknowledgment.map { $0.rawValue },
            "lowReservoirReminderValue": lowReservoirReminderValue,
            "podAttachmentConfirmed": podAttachmentConfirmed,
            "confidenceRemindersEnabled": confidenceRemindersEnabled,
            "acknowledgedTimeOffsetAlert": acknowledgedTimeOffsetAlert,
            "initialConfigurationCompleted": initialConfigurationCompleted,
            "onboardingCompleted": onboardingCompleted
        ]
        
        rawValue["lastPodCommState"] = try? JSONEncoder().encode(lastPodCommState)
        rawValue["lastPodCommDate"] = lastPodCommDate
        rawValue["suspendState"] = suspendState?.rawValue
        rawValue["lastStatusDate"] = lastStatusDate
        rawValue["reservoirLevel"] = reservoirLevel?.rawValue
        rawValue["podTotalDelivery"] = podTotalDelivery
        rawValue["lastStatusDate"] = lastStatusDate
        rawValue["podActivatedAt"] = podActivatedAt
        rawValue["unfinalizedBolus"] = unfinalizedBolus?.rawValue
        rawValue["unfinalizedTempBasal"] = unfinalizedTempBasal?.rawValue
        rawValue["alarmCode"] = alarmCode?.rawValue
        rawValue["pendingCommand"] = pendingCommand?.rawValue
        rawValue["scheduledExpirationReminderOffset"] = scheduledExpirationReminderOffset
        rawValue["defaultExpirationReminderOffset"] = defaultExpirationReminderOffset

        return rawValue
    }
    
    mutating func updateFromPodStatus(status: PodStatus) {
        lastStatusDate = dateGenerator()
        reservoirLevel = ReservoirLevel(rawValue: status.reservoirUnitsRemaining)
        podActivatedAt = status.expirationDate - Pod.lifetime
        podTotalDelivery = status.delivered
    }

    mutating func finalizeDoses() {
        if let bolus = unfinalizedBolus, bolus.isFinished(at: dateGenerator()) {
            finishedDoses.append(bolus)
            unfinalizedBolus = nil
        }

        if let tempBasal = unfinalizedTempBasal, tempBasal.isFinished(at: dateGenerator()) {
            finishedDoses.append(tempBasal)
            unfinalizedTempBasal = nil
        }

    }
}

extension DashPumpManagerState: CustomDebugStringConvertible {
    public var debugDescription: String {
        return [
            "* podActivatedAt: \(String(describing: podActivatedAt))",
            "* timeZone: \(timeZone)",
            "* suspendState: \(String(describing: suspendState))",
            "* basalProgram: \(basalProgram)",
            "* finishedDoses: \(finishedDoses)",
            "* unfinalizedBolus: \(String(describing: unfinalizedBolus))",
            "* unfinalizedTempBasal: \(String(describing: unfinalizedTempBasal))",
            "* reservoirLevel: \(String(describing: reservoirLevel))",
            "* lastStatusDate: \(String(describing: lastStatusDate))",
            "* pendingCommand: \(String(describing: pendingCommand))",
            "* connectionState: \(String(describing: connectionState))",
            "* lowReservoirReminderValue: \(lowReservoirReminderValue)",
            "* scheduledExpirationReminderOffset: \(String(describing: scheduledExpirationReminderOffset))",
            "* defaultExpirationReminderOffset: \(defaultExpirationReminderOffset)",
            "* podAttachmentConfirmed: \(podAttachmentConfirmed)",
            "* activeAlerts: \(activeAlerts)",
            "* alertsWithPendingAcknowledgment: \(alertsWithPendingAcknowledgment)",
            "* confidenceRemindersEnabled: \(confidenceRemindersEnabled)",
            "* acknowledgedTimeOffsetAlert: \(acknowledgedTimeOffsetAlert)",
            "* initialConfigurationCompleted: \(initialConfigurationCompleted)",
            "* onboardingCompleted: \(onboardingCompleted)"
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
