//
//  MockPodStatus.swift
//  DashKit
//
//  Created by Pete Schwamb on 3/9/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import PodSDK

public struct MockPodStatus: PodStatus, Equatable {

    public var activationDate: Date

    public var podState: PodState

    public var programStatus: ProgramStatus

    public var activeAlerts: PodAlerts

    public var isOcclusionAlertActive: Bool

    public var bolusUnitsRemaining: Int

    public var insulinDelivered: Double

    public var totalUnitsDelivered: Int {
        return Int(insulinDelivered / Pod.podSDKInsulinMultiplier)
    }

    public var initialInsulinAmount: Double

    public var reservoirUnitsRemaining: Int {
        get {
            let remaining = initialInsulinAmount - insulinDelivered
            
            if remaining > Pod.maximumReservoirReading {
                return ReservoirLevel.aboveThresholdMagicNumber
            } else {
                return max(0, Int((remaining * Pod.pulsesPerUnit).rounded() / Pod.pulsesPerUnit * Pod.podSDKInsulinMultiplier))
            }
        }
    }

    public var timeElapsedSinceActivation: TimeInterval {
        return Date().timeIntervalSince(activationDate)
    }

    public var expirationDate: Date {
        return activationDate.addingTimeInterval(Pod.lifetime)
    }

    public func hasAlerts() -> Bool {
        return !activeAlerts.isEmpty
    }
    
    private var lastDeliveryUpdate: Date
    
    public var basalProgram: BasalProgram?
    public var basalProgramStartDate: Date?
    public var basalProgramStartOffset: Double?
    
    public var bolus: UnfinalizedDose? {
        didSet {
            self.bolusUnitsRemaining = 0
        }
    }
    
    public var tempBasal: UnfinalizedDose?

    public init(activationDate: Date,
                podState: PodState,
                programStatus: ProgramStatus,
                activeAlerts: PodAlerts,
                isOcclusionAlertActive: Bool,
                bolusUnitsRemaining: Int,
                initialInsulinAmount: Double,
                insulinDelivered: Double = 0)
    {
        self.activationDate = activationDate
        self.podState = podState
        self.programStatus = programStatus
        self.activeAlerts = activeAlerts
        self.isOcclusionAlertActive = isOcclusionAlertActive
        self.bolusUnitsRemaining = bolusUnitsRemaining
        self.initialInsulinAmount = initialInsulinAmount
        self.insulinDelivered = 0
        self.lastDeliveryUpdate = Date()
    }
    
    public static var normal: MockPodStatus {
        let activation = Date().addingTimeInterval(.hours(-2))
        return MockPodStatus(
            activationDate: activation,
            podState: .runningAboveMinVolume,
            programStatus: .basalRunning,
            activeAlerts: PodAlerts([]),
            isOcclusionAlertActive: false,
            bolusUnitsRemaining: 0,
            initialInsulinAmount: 11,
            insulinDelivered: 100)
    }
    
    mutating func updateDelivery() {
        guard let basalProgram = basalProgram,
              let basalProgramStartDate = basalProgramStartDate,
              let basalProgramStartOffset = basalProgramStartOffset
        else {
            return
        }
        
        let now = Date()
        
        let scheduleIter = basalProgram.basalSegments.makeInfiniteLoopIterator()
        
        let scheduleTimeSpan = TimeInterval(hours: 24)
        
        let slotDuration = TimeInterval(minutes: 30)

        var offset = (basalProgramStartOffset + lastDeliveryUpdate.timeIntervalSince(basalProgramStartDate))
        let endingOffset = (basalProgramStartOffset + now.timeIntervalSince(basalProgramStartDate))

        var segment = scheduleIter.next()!
        
        var basalDelivery: Double = 0
                
        while offset.truncatingRemainder(dividingBy: scheduleTimeSpan) > Double(segment.endTime) * slotDuration {
            segment = scheduleIter.next()!
        }
        
        while offset < endingOffset {
            let clockOffset = offset.truncatingRemainder(dividingBy: scheduleTimeSpan)
            let segmentRemaining = Double(segment.endTime) * slotDuration - clockOffset
            let deliveryEnd = min(offset + segmentRemaining, endingOffset)
            let deliveryTime = deliveryEnd - offset
            basalDelivery += deliveryTime.hours * Double(segment.basalRate) / Pod.podSDKInsulinMultiplier
            
            offset += segmentRemaining
            segment = scheduleIter.next()!
        }
        insulinDelivered += basalDelivery

        if let bolus = bolus, bolus.isFinished(at: now) {
            insulinDelivered += bolus.units
        }
        
        if let tempBasal = tempBasal, tempBasal.isFinished(at: now) {
            insulinDelivered = tempBasal.units
        }

        self.lastDeliveryUpdate = now
    }
    
    mutating func cancelBolus(at now: Date = Date()) {
        guard var bolus = bolus else {
            return
        }
        
        if bolus.isFinished(at: now) {
            self.insulinDelivered += bolus.units
            self.bolus = nil
            return
        }
        
        bolus.cancel(at: now)
        
        self.insulinDelivered += bolus.units
        self.bolus = nil
        let remaining = (bolus.programmedUnits ?? bolus.units) - bolus.units
        self.bolusUnitsRemaining = Int((remaining * Pod.pulsesPerUnit).rounded() / Pod.pulsesPerUnit * Pod.podSDKInsulinMultiplier)
    }
    
    mutating func cancelTempBasal(at now: Date = Date()) {
        guard var tempBasal = tempBasal else {
            return
        }
        
        tempBasal.cancel(at: now)
        self.insulinDelivered += tempBasal.units
        self.tempBasal = nil
    }

}

extension MockPodStatus: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard
            let activationDate = rawValue["activationDate"] as? Date,
            let rawPodState = rawValue["podState"] as? PodState.RawValue,
            let podState = PodState(rawValue: rawPodState),
            let rawProgramStatus = rawValue["programStatus"] as? ProgramStatus.RawValue,
            let rawActiveAlerts = rawValue["activeAlerts"] as? PodAlerts.RawValue,
            let isOcclusionAlertActive = rawValue["isOcclusionAlertActive"] as? Bool,
            let bolusUnitsRemaining = rawValue["bolusUnitsRemaining"] as? Int,
            let insulinDelivered = rawValue["insulinDelivered"] as? Double,
            let initialInsulinAmount = rawValue["initialInsulinAmount"] as? Double,
            let lastDeliveryUpdate = rawValue["lastDeliveryUpdate"] as? Date
            else
        {
            return nil
        }

        self.activationDate = activationDate
        self.podState = podState
        self.programStatus = ProgramStatus(rawValue: rawProgramStatus)
        self.activeAlerts = PodAlerts(rawValue: rawActiveAlerts)
        self.isOcclusionAlertActive = isOcclusionAlertActive
        self.bolusUnitsRemaining = bolusUnitsRemaining
        self.insulinDelivered = insulinDelivered
        self.initialInsulinAmount = initialInsulinAmount
        self.lastDeliveryUpdate = lastDeliveryUpdate
        
        if let rawBasalProgram = rawValue["basalProgram"] as? BasalProgram.RawValue,
           let basalProgram = BasalProgram(rawValue: rawBasalProgram)
        {
            self.basalProgram = basalProgram
        }
        
        if let basalProgramStartDate = rawValue["basalProgramStartDate"] as? Date {
            self.basalProgramStartDate = basalProgramStartDate
        }

        if let basalProgramStartOffset = rawValue["basalProgramStartOffset"] as? Double {
            self.basalProgramStartOffset = basalProgramStartOffset
        }

    }
    
    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "activationDate": activationDate,
            "podState": podState.rawValue,
            "programStatus": programStatus.rawValue,
            "activeAlerts": activeAlerts.rawValue,
            "isOcclusionAlertActive": isOcclusionAlertActive,
            "bolusUnitsRemaining": bolusUnitsRemaining,
            "insulinDelivered": insulinDelivered,
            "initialInsulinAmount": initialInsulinAmount,
            "lastDeliveryUpdate": lastDeliveryUpdate
        ]
        
        if let basalProgram = basalProgram {
            rawValue["basalProgram"] = basalProgram.rawValue
        }
        
        if let basalProgramStartDate = basalProgramStartDate {
            rawValue["basalProgramStartDate"] = basalProgramStartDate
        }
        
        if let basalProgramStartOffset = basalProgramStartOffset {
            rawValue["basalProgramStartOffset"] = basalProgramStartOffset
        }
        
        return rawValue
    }
}
