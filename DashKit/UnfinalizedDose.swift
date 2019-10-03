//
//  UnfinalizedDose.swift
//  DashKit
//
//  Created by Pete Schwamb on 5/31/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import LoopKit

public struct UnfinalizedDose: RawRepresentable, Equatable, CustomStringConvertible {
    public typealias RawValue = [String: Any]

    enum DoseType: Int {
        case bolus = 0
        case tempBasal
        case suspend
        case resume
    }

    enum ScheduledCertainty: Int {
        case certain = 0
        case uncertain

        public var localizedDescription: String {
            switch self {
            case .certain:
                return LocalizedString("Certain", comment: "String describing a dose that was certainly scheduled")
            case .uncertain:
                return LocalizedString("Uncertain", comment: "String describing a dose that was possibly scheduled")
            }
        }
    }

    private let insulinFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 3
        return formatter
    }()

    private let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    private let dateFormatter = ISO8601DateFormatter()

    fileprivate var uniqueKey: Data {
        return "\(doseType) \(scheduledUnits ?? units) \(dateFormatter.string(from: startTime))".data(using: .utf8)!
    }

    let doseType: DoseType
    public var units: Double
    var scheduledUnits: Double?     // Tracks the scheduled units, as boluses may be canceled before finishing, at which point units would reflect actual delivered volume.
    var scheduledTempRate: Double?  // Tracks the original temp rate, as during finalization the units are discretized to pump pulses, changing the actual rate
    let startTime: Date
    var duration: TimeInterval?
    var scheduledCertainty: ScheduledCertainty

    var endTime: Date? {
        get {
            return duration != nil ? startTime.addingTimeInterval(duration!) : nil
        }
        set {
            duration = newValue?.timeIntervalSince(startTime)
        }
    }

    public func progress(at date: Date) -> Double {
        guard let duration = duration else {
            return 0
        }
        let elapsed = -startTime.timeIntervalSince(date)
        return min(elapsed / duration, 1)
    }

    public func isFinished(at date: Date) -> Bool {
        return progress(at: date) >= 1
    }

    // Units per hour
    public var rate: Double {
        guard let duration = duration else {
            return 0
        }
        return units / duration.hours
    }
    
    public func finalizedUnits(at date: Date) -> Double? {
        guard isFinished(at: date) else {
            return nil
        }
        return units
    }

    init(bolusAmount: Double, startTime: Date, scheduledCertainty: ScheduledCertainty) {
        self.doseType = .bolus
        self.units = bolusAmount
        self.startTime = startTime
        self.duration = TimeInterval(bolusAmount / Pod.bolusDeliveryRate)
        self.scheduledCertainty = scheduledCertainty
        self.scheduledUnits = nil
    }

    init(tempBasalRate: Double, startTime: Date, duration: TimeInterval, scheduledCertainty: ScheduledCertainty) {
        self.doseType = .tempBasal
        self.units = tempBasalRate * duration.hours
        self.startTime = startTime
        self.duration = duration
        self.scheduledCertainty = scheduledCertainty
        self.scheduledUnits = nil
    }

    init(suspendStartTime: Date, scheduledCertainty: ScheduledCertainty) {
        self.doseType = .suspend
        self.units = 0
        self.startTime = suspendStartTime
        self.scheduledCertainty = scheduledCertainty
    }

    init(resumeStartTime: Date, scheduledCertainty: ScheduledCertainty) {
        self.doseType = .resume
        self.units = 0
        self.startTime = resumeStartTime
        self.scheduledCertainty = scheduledCertainty
    }

    public mutating func cancel(at date: Date, withRemaining remainingHundredths: Int? = nil) {
        guard scheduledUnits == nil else {
            // Already canceled
            return
        }
        scheduledUnits = units
        let oldRate = rate
        duration = date.timeIntervalSince(startTime)
        if let remainingHundredths = remainingHundredths {
            units = units - (Double(remainingHundredths) / Pod.podSDKInsulinMultiplier)
        } else if let duration = duration {
            units = floor(oldRate * duration.hours * Pod.pulsesPerUnit) / Pod.pulsesPerUnit
        }
    }

    public var description: String {
        let unitsStr = insulinFormatter.string(from: units) ?? ""
        let startTimeStr = shortDateFormatter.string(from: startTime)
        let durationStr = duration?.format(using: [.minute, .second]) ?? ""
        switch doseType {
        case .bolus:
            if let scheduledUnits = scheduledUnits {
                let scheduledUnitsStr = insulinFormatter.string(from: scheduledUnits) ?? "?"
                return String(format: LocalizedString("InterruptedBolus: %1$@ U (%2$@ U scheduled) %3$@ %4$@ %5$@", comment: "The format string describing a bolus that was interrupted. (1: The amount delivered)(2: The amount scheduled)(3: Start time of the dose)(4: duration)(5: scheduled certainty)"), unitsStr, scheduledUnitsStr, startTimeStr, durationStr, scheduledCertainty.localizedDescription)
            } else {
                return String(format: LocalizedString("Bolus: %1$@U %2$@ %3$@ %4$@", comment: "The format string describing a bolus. (1: The amount delivered)(2: Start time of the dose)(3: duration)(4: scheduled certainty)"), unitsStr, startTimeStr, durationStr, scheduledCertainty.localizedDescription)
            }
        case .tempBasal:
            let rateStr = NumberFormatter.localizedString(from: NSNumber(value: rate), number: .decimal)
            return String(format: LocalizedString("TempBasal: %1$@ U/hour %2$@ %3$@ %4$@", comment: "The format string describing a temp basal. (1: The rate)(2: Start time)(3: duration)(4: scheduled certainty"), rateStr, startTimeStr, durationStr, scheduledCertainty.localizedDescription)
        case .suspend:
            return String(format: LocalizedString("Suspend: %1$@ %2$@", comment: "The format string describing a suspend. (1: Time)(2: Scheduled certainty"), startTimeStr, scheduledCertainty.localizedDescription)
        case .resume:
            return String(format: LocalizedString("Resume: %1$@ %2$@", comment: "The format string describing a resume. (1: Time)(2: Scheduled certainty"), startTimeStr, scheduledCertainty.localizedDescription)
        }
    }

    // RawRepresentable
    public init?(rawValue: RawValue) {
        guard
            let rawDoseType = rawValue["doseType"] as? Int,
            let doseType = DoseType(rawValue: rawDoseType),
            let units = rawValue["units"] as? Double,
            let startTime = rawValue["startTime"] as? Date,
            let rawScheduledCertainty = rawValue["scheduledCertainty"] as? Int,
            let scheduledCertainty = ScheduledCertainty(rawValue: rawScheduledCertainty)
            else {
                return nil
        }

        self.doseType = doseType
        self.units = units
        self.startTime = startTime
        self.scheduledCertainty = scheduledCertainty

        if let scheduledUnits = rawValue["scheduledUnits"] as? Double {
            self.scheduledUnits = scheduledUnits
        }

        if let scheduledTempRate = rawValue["scheduledTempRate"] as? Double {
            self.scheduledTempRate = scheduledTempRate
        }

        if let duration = rawValue["duration"] as? Double {
            self.duration = duration
        }
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "doseType": doseType.rawValue,
            "units": units,
            "startTime": startTime,
            "scheduledCertainty": scheduledCertainty.rawValue
        ]

        if let scheduledUnits = scheduledUnits {
            rawValue["scheduledUnits"] = scheduledUnits
        }

        if let scheduledTempRate = scheduledTempRate {
            rawValue["scheduledTempRate"] = scheduledTempRate
        }

        if let duration = duration {
            rawValue["duration"] = duration
        }

        return rawValue
    }
}

private extension TimeInterval {
    func format(using units: NSCalendar.Unit) -> String? {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = units
        formatter.unitsStyle = .full
        formatter.zeroFormattingBehavior = .dropLeading
        formatter.maximumUnitCount = 2

        return formatter.string(from: self)
    }
}

extension NewPumpEvent {
    init(_ dose: UnfinalizedDose, at date: Date) {
        let title = String(describing: dose)
        let entry = DoseEntry(dose, at: date)
        self.init(date: dose.startTime, dose: entry, isMutable: !dose.isFinished(at: date), raw: dose.uniqueKey, title: title)
    }
}

extension DoseEntry {
    init (_ dose: UnfinalizedDose, at date: Date) {
        switch dose.doseType {
        case .bolus:
            self = DoseEntry(type: .bolus, startDate: dose.startTime, endDate: dose.endTime, value: dose.scheduledUnits ?? dose.units, unit: .units, deliveredUnits: dose.finalizedUnits(at: date))
        case .tempBasal:
            self = DoseEntry(type: .tempBasal, startDate: dose.startTime, endDate: dose.endTime, value: dose.scheduledTempRate ?? dose.rate, unit: .unitsPerHour, deliveredUnits: dose.finalizedUnits(at: date))
        case .suspend:
            self = DoseEntry(suspendDate: dose.startTime)
        case .resume:
            self = DoseEntry(resumeDate: dose.startTime)
        }
    }
}

extension UnfinalizedDose {
    func doseEntry(at date: Date) -> DoseEntry {
        return DoseEntry(self, at: date)
    }
}
