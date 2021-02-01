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

    public var bolusUnitsRemaining: Int

    public var insulinDelivered: Double
    
    public var lowReservoirAlert: LowReservoirAlert?

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
    
    public var podCommState: PodCommState

    public var timeElapsedSinceActivation: TimeInterval {
        return Date().timeIntervalSince(activationDate)
    }

    public var expirationDate: Date {
        return activationDate.addingTimeInterval(Pod.lifetime)
    }

    public func hasAlerts() -> Bool {
        return !activeAlerts.isEmpty
    }
    
    public var alarmDetail: PodAlarmDetail? {
        guard let alarmCode = alarmCode,
              let alarmDescription = alarmDescription,
              let occlusionType = occlusionType,
              let didErrorOccuredFetchingBolusInfo = didErrorOccuredFetchingBolusInfo,
              let wasBolusActiveWhenPodAlarmed = wasBolusActiveWhenPodAlarmed,
              let podStateWhenPodAlarmed = podStateWhenPodAlarmed,
              let alarmDate = alarmDate,
              let alarmReferenceCode = alarmReferenceCode else
        {
            return nil
        }
            
        return MockPodAlarm(alarmCode: alarmCode, alarmDescription: alarmDescription, podStatus: self, occlusionType: occlusionType, didErrorOccuredFetchingBolusInfo: didErrorOccuredFetchingBolusInfo, wasBolusActiveWhenPodAlarmed: wasBolusActiveWhenPodAlarmed, podStateWhenPodAlarmed: podStateWhenPodAlarmed, alarmTime: alarmDate, activationTime: activationDate, referenceCode: alarmReferenceCode)
    }
    
    public mutating func enterAlarmState(alarmCode: AlarmCode, alarmDescription: String, didErrorOccuredFetchingBolusInfo: Bool, alarmDate: Date, referenceCode: String) {
        
        self.alarmCode = alarmCode
        self.alarmDescription = alarmDescription
        self.didErrorOccuredFetchingBolusInfo = didErrorOccuredFetchingBolusInfo
        self.alarmDate = alarmDate
        self.alarmReferenceCode = referenceCode
        
        self.podStateWhenPodAlarmed = podState
        podState = .alarm
        programStatus = ProgramStatus(rawValue: 0)
        if case .occlusion = alarmCode {
            occlusionType = .stallDuringRuntimeWire1TimingOut
        } else {
            occlusionType = OcclusionType.none
        }
        
        self.wasBolusActiveWhenPodAlarmed = bolus != nil
        bolus?.cancel(at: alarmDate)
        tempBasal?.cancel(at: alarmDate)
    }
    
    private var lastDeliveryUpdate: Date
    
    public var basalProgram: BasalProgram?
    public var basalProgramStartDate: Date?
    public var basalProgramStartOffset: Double?
    
    // Data for AlarmDetail
    public var alarmCode: AlarmCode?
    public var alarmDescription: String?
    public var occlusionType: OcclusionType?
    public var didErrorOccuredFetchingBolusInfo: Bool?
    public var wasBolusActiveWhenPodAlarmed: Bool?
    public var podStateWhenPodAlarmed: PodState?
    public var alarmDate: Date?
    public var alarmReferenceCode: String?
    
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
                bolusUnitsRemaining: Int,
                initialInsulinAmount: Double,
                insulinDelivered: Double = 0,
                basalProgram: BasalProgram? = nil,
                podCommState: PodCommState = .active)
    {
        self.activationDate = activationDate
        self.podState = podState
        self.programStatus = programStatus
        self.activeAlerts = activeAlerts
        self.bolusUnitsRemaining = bolusUnitsRemaining
        self.initialInsulinAmount = initialInsulinAmount
        self.insulinDelivered = insulinDelivered
        self.lastDeliveryUpdate = Date()
        self.basalProgram = basalProgram
        self.podCommState = podCommState
    }
    
    public static var normal: MockPodStatus {
        let activation = Date().addingTimeInterval(.hours(-2))
        let segments = [try! BasalSegment(startTime: 0, endTime: 24, basalRate: 1000),
                        try! BasalSegment(startTime: 24, endTime: 48, basalRate: 1500)]
        
        return MockPodStatus(
            activationDate: activation,
            podState: .runningAboveMinVolume,
            programStatus: .basalRunning,
            activeAlerts: PodAlerts([]),
            bolusUnitsRemaining: 0,
            initialInsulinAmount: 11,
            insulinDelivered: 100,
            basalProgram: try! BasalProgram(basalSegments: segments))
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
            self.bolus = nil
        }
        
        if let tempBasal = tempBasal, tempBasal.isFinished(at: now) {
            insulinDelivered = tempBasal.units
            self.tempBasal = nil
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
    
    var lowReservoirAlertConditionActive: Bool {
        if let lowReservoirAlert = lowReservoirAlert {
            return Int((initialInsulinAmount - insulinDelivered) * Pod.podSDKInsulinMultiplier.rawValue) <= lowReservoirAlert.reservoirVolumeBelow
        }
        return false
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
            let bolusUnitsRemaining = rawValue["bolusUnitsRemaining"] as? Int,
            let insulinDelivered = rawValue["insulinDelivered"] as? Double,
            let initialInsulinAmount = rawValue["initialInsulinAmount"] as? Double,
            let lastDeliveryUpdate = rawValue["lastDeliveryUpdate"] as? Date,
            let rawPodCommState = rawValue["podCommState"] as? Data,
            let podCommState = try? JSONDecoder().decode(PodCommState.self, from: rawPodCommState)
            else
        {
            return nil
        }

        self.activationDate = activationDate
        self.podState = podState
        self.programStatus = ProgramStatus(rawValue: rawProgramStatus)
        self.activeAlerts = PodAlerts(rawValue: rawActiveAlerts)
        self.bolusUnitsRemaining = bolusUnitsRemaining
        self.insulinDelivered = insulinDelivered
        self.initialInsulinAmount = initialInsulinAmount
        self.lastDeliveryUpdate = lastDeliveryUpdate
        self.podCommState = podCommState
        
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

        if let rawAlarmCode = rawValue["alarmCode"] as? AlarmCode.RawValue,
           let alarmCode = AlarmCode(rawValue: rawAlarmCode)
        {
            self.alarmCode = alarmCode
        }
            
        if let alarmDescription = rawValue["alarmDescription"] as? String {
            self.alarmDescription = alarmDescription
        }
        
        if let rawOcclusionType = rawValue["occlusionType"] as? OcclusionType.RawValue,
           let occlusionType = OcclusionType(rawValue: rawOcclusionType)
        {
            self.occlusionType = occlusionType
        }
        
        if let didErrorOccuredFetchingBolusInfo = rawValue["didErrorOccuredFetchingBolusInfo"] as? Bool {
            self.didErrorOccuredFetchingBolusInfo = didErrorOccuredFetchingBolusInfo
        }
        
        if let wasBolusActiveWhenPodAlarmed = rawValue["wasBolusActiveWhenPodAlarmed"] as? Bool {
            self.wasBolusActiveWhenPodAlarmed = wasBolusActiveWhenPodAlarmed
        }

        if let rawPodStateWhenPodAlarmed = rawValue["podStateWhenPodAlarmed"] as? PodState.RawValue,
           let podStateWhenPodAlarmed = PodState(rawValue: rawPodStateWhenPodAlarmed)
        {
            self.podStateWhenPodAlarmed = podStateWhenPodAlarmed
        }

        if let alarmDate = rawValue["alarmDate"] as? Date {
            self.alarmDate = alarmDate
        }

        if let alarmReferenceCode = rawValue["alarmReferenceCode"] as? String {
            self.alarmReferenceCode = alarmReferenceCode
        }
        
        if let lowReservoirAlertRaw = rawValue["lowReservoirAlert"] as? LowReservoirAlert.RawValue, let lowReservoirAlert = LowReservoirAlert(rawValue: lowReservoirAlertRaw)
        {
            self.lowReservoirAlert = lowReservoirAlert
        }

    }
    
    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "activationDate": activationDate,
            "podState": podState.rawValue,
            "programStatus": programStatus.rawValue,
            "activeAlerts": activeAlerts.rawValue,
            "bolusUnitsRemaining": bolusUnitsRemaining,
            "insulinDelivered": insulinDelivered,
            "initialInsulinAmount": initialInsulinAmount,
            "lastDeliveryUpdate": lastDeliveryUpdate
        ]
        
        rawValue["basalProgram"] = basalProgram?.rawValue
        rawValue["basalProgramStartDate"] = basalProgramStartDate
        rawValue["basalProgramStartOffset"] = basalProgramStartOffset
        rawValue["alarmCode"] = alarmCode?.rawValue
        rawValue["alarmDescription"] = alarmDescription
        rawValue["occlusionType"] = occlusionType?.rawValue
        rawValue["didErrorOccuredFetchingBolusInfo"] = didErrorOccuredFetchingBolusInfo
        rawValue["wasBolusActiveWhenPodAlarmed"] = wasBolusActiveWhenPodAlarmed
        rawValue["podStateWhenPodAlarmed"] = podStateWhenPodAlarmed?.rawValue
        rawValue["alarmDate"] = alarmDate
        rawValue["alarmReferenceCode"] = alarmReferenceCode
        rawValue["podCommState"] = try? JSONEncoder().encode(podCommState)
        rawValue["lowReservoirAlert"] = lowReservoirAlert?.rawValue

        return rawValue
    }
}

extension LowReservoirAlert: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard let reservoirVolumeBelow = rawValue["reservoirVolumeBelow"] as? Int else {
            return nil
        }
        
        try? self.init(reservoirVolumeBelow: reservoirVolumeBelow)
    }
    
    public var rawValue: RawValue {
        let rawValue: RawValue = [
            "reservoirVolumeBelow": reservoirVolumeBelow,
        ]
        return rawValue
    }
}
