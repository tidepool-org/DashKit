//
//  UnfinalizedDoseTests.swift
//  DashKitTests
//
//  Created by Pete Schwamb on 11/11/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import XCTest
import LoopKit
@testable import DashKit

class UnfinalizedDoseTests: XCTestCase {
    func testBolusCancelLongAfterFinishTime() {
        let start = Date()
        var dose = UnfinalizedDose(bolusAmount: 1, startTime: start, scheduledCertainty: .certain)
        dose.cancel(at: start + .hours(2))
        
        XCTAssertEqual(1.0, dose.units)
    }
    
    func testInitializationBolus() {
        let amount = 3.5
        let startTime = Date()
        let duration = TimeInterval(amount / Pod.bolusDeliveryRate)
        let unfinalizedBolus = UnfinalizedDose(bolusAmount: amount,
                                               startTime: startTime,
                                               scheduledCertainty: .certain)
        XCTAssertEqual(unfinalizedBolus.doseType, .bolus)
        XCTAssertEqual(unfinalizedBolus.units, amount)
        XCTAssertNil(unfinalizedBolus.programmedUnits)
        XCTAssertNil(unfinalizedBolus.programmedRate)
        XCTAssertEqual(unfinalizedBolus.startTime, startTime)
        XCTAssertEqual(unfinalizedBolus.duration, duration)
        XCTAssertEqual(unfinalizedBolus.scheduledCertainty, .certain)
        XCTAssertEqual(unfinalizedBolus.endTime, startTime.addingTimeInterval(duration))
        XCTAssertEqual(unfinalizedBolus.rate, amount/duration.hours)
    }
    
    func testInitializationTBR() {
        let amount = 0.5
        let startTime = Date()
        let duration = TimeInterval.minutes(30)
        let unfinalizedTBR = UnfinalizedDose(tempBasalRate: amount,
                                               startTime: startTime,
                                               duration: duration,
                                               scheduledCertainty: .certain)
        XCTAssertEqual(unfinalizedTBR.doseType, .tempBasal)
        XCTAssertEqual(unfinalizedTBR.units, amount*duration.hours)
        XCTAssertNil(unfinalizedTBR.programmedUnits)
        XCTAssertNil(unfinalizedTBR.programmedRate)
        XCTAssertEqual(unfinalizedTBR.startTime, startTime)
        XCTAssertEqual(unfinalizedTBR.duration, duration)
        XCTAssertEqual(unfinalizedTBR.scheduledCertainty, .certain)
        XCTAssertEqual(unfinalizedTBR.endTime, startTime.addingTimeInterval(duration))
        XCTAssertEqual(unfinalizedTBR.rate, amount)
    }
    
    func testInitializatinSuspend() {
        let startTime = Date()
        let unfinalizedSuspend = UnfinalizedDose(suspendStartTime: startTime,
                                                 scheduledCertainty: .certain)
        XCTAssertEqual(unfinalizedSuspend.doseType, .suspend)
        XCTAssertEqual(unfinalizedSuspend.units, 0)
        XCTAssertNil(unfinalizedSuspend.programmedUnits)
        XCTAssertNil(unfinalizedSuspend.programmedRate)
        XCTAssertEqual(unfinalizedSuspend.startTime, startTime)
        XCTAssertNil(unfinalizedSuspend.duration)
        XCTAssertEqual(unfinalizedSuspend.scheduledCertainty, .certain)
        XCTAssertNil(unfinalizedSuspend.endTime)
        XCTAssertEqual(unfinalizedSuspend.rate, 0)
    }
    
    func testInitializationResume() {
        let startTime = Date()
        let unfinalizedResume = UnfinalizedDose(resumeStartTime: startTime,
                                                scheduledCertainty: .certain)
        XCTAssertEqual(unfinalizedResume.doseType, .resume)
        XCTAssertEqual(unfinalizedResume.units, 0)
        XCTAssertNil(unfinalizedResume.programmedUnits)
        XCTAssertNil(unfinalizedResume.programmedRate)
        XCTAssertEqual(unfinalizedResume.startTime, startTime)
        XCTAssertNil(unfinalizedResume.duration)
        XCTAssertEqual(unfinalizedResume.scheduledCertainty, .certain)
        XCTAssertNil(unfinalizedResume.endTime)
        XCTAssertEqual(unfinalizedResume.rate, 0)
    }
    
    func testProgress() {
        let amount = 3.5
        let startTime = Date()
        let duration = TimeInterval(amount / Pod.bolusDeliveryRate)
        let unfinalizedBolus = UnfinalizedDose(bolusAmount: amount,
                                               startTime: startTime,
                                               scheduledCertainty: .certain)
        XCTAssertEqual(unfinalizedBolus.progress(at: startTime + .seconds(30)), .seconds(30) / duration)
        XCTAssertEqual(unfinalizedBolus.progress(at: startTime + .seconds(300)), 1)
    }
    
    func testIsFinished() {
        let amount = 0.5
        let startTime = Date()
        let duration = TimeInterval.minutes(30)
        let unfinalizedTBR = UnfinalizedDose(tempBasalRate: amount,
                                             startTime: startTime,
                                             duration: duration,
                                             scheduledCertainty: .certain)
        XCTAssertFalse(unfinalizedTBR.isFinished(at: startTime + .minutes(25)))
        XCTAssertTrue(unfinalizedTBR.isFinished(at: startTime + .minutes(31)))
    }
    
    func testFinalizedUnits() {
        let amount = 3.5
        let startTime = Date()
        let unfinalizedBolus = UnfinalizedDose(bolusAmount: amount,
                                               startTime: startTime,
                                               scheduledCertainty: .certain)
        XCTAssertNil(unfinalizedBolus.finalizedUnits(at: startTime + .seconds(30)))
        XCTAssertEqual(unfinalizedBolus.finalizedUnits(at: startTime + .seconds(300)), amount)
    }
        
    func testCancel() {
        let start = Date()
        var dose = UnfinalizedDose(bolusAmount: 3, startTime: start, scheduledCertainty: .certain)
        dose.cancel(at: start + .minutes(1))
        
        XCTAssertEqual(dose.units, Pod.bolusDeliveryRate * .minutes(1))
    }
    
    func testCancelWithTimeShiftKeepsFullDose() {
        let start = Date()
        var dose = UnfinalizedDose(bolusAmount: 3, startTime: start, scheduledCertainty: .certain)
        dose.cancel(at: start - .hours(1))
        XCTAssertEqual(3, dose.units)
    }

    func testRawValue() {
        let amount = 3.5
        let startTime = Date()
        let duration = TimeInterval(amount / Pod.bolusDeliveryRate)
        let unfinalizedBolus = UnfinalizedDose(bolusAmount: amount,
                                               startTime: startTime,
                                               scheduledCertainty: .certain)
        let rawValue = unfinalizedBolus.rawValue
        XCTAssertEqual(UnfinalizedDose.DoseType(rawValue: rawValue["rawDoseType"] as! UnfinalizedDose.DoseType.RawValue), .bolus)
        XCTAssertEqual(rawValue["units"] as! Double, amount)
        XCTAssertEqual(rawValue["startTime"] as! Date, startTime)
        XCTAssertEqual(UnfinalizedDose.ScheduledCertainty(rawValue: rawValue["rawScheduledCertainty"] as! UnfinalizedDose.ScheduledCertainty.RawValue), .certain)
        XCTAssertNil(rawValue["programmedUnits"])
        XCTAssertNil(rawValue["programmedRate"])
        XCTAssertEqual(rawValue["duration"] as! Double, duration)
    }
    
    func testRawValueBolusWithProgrammedUnits() {
        let amount = 3.5
        let startTime = Date()
        let duration = TimeInterval(amount / Pod.bolusDeliveryRate)
        var unfinalizedBolus = UnfinalizedDose(bolusAmount: amount,
                                               startTime: startTime,
                                               scheduledCertainty: .certain)
        unfinalizedBolus.programmedUnits = amount
        let rawValue = unfinalizedBolus.rawValue
        XCTAssertEqual(UnfinalizedDose.DoseType(rawValue: rawValue["rawDoseType"] as! UnfinalizedDose.DoseType.RawValue), .bolus)
        XCTAssertEqual(rawValue["units"] as! Double, amount)
        XCTAssertEqual(rawValue["startTime"] as! Date, startTime)
        XCTAssertEqual(UnfinalizedDose.ScheduledCertainty(rawValue: rawValue["rawScheduledCertainty"] as! UnfinalizedDose.ScheduledCertainty.RawValue), .certain)
        XCTAssertEqual(rawValue["programmedUnits"] as! Double, amount)
        XCTAssertNil(rawValue["programmedRate"])
        XCTAssertEqual(rawValue["duration"] as! Double, duration)
        
        let restoredUnfinalizedBolus = UnfinalizedDose(rawValue: rawValue)!
        XCTAssertEqual(restoredUnfinalizedBolus.doseType, unfinalizedBolus.doseType)
        XCTAssertEqual(restoredUnfinalizedBolus.units, unfinalizedBolus.units)
        XCTAssertEqual(restoredUnfinalizedBolus.programmedUnits, unfinalizedBolus.programmedUnits)
        XCTAssertEqual(restoredUnfinalizedBolus.programmedRate, unfinalizedBolus.programmedRate)
        XCTAssertEqual(restoredUnfinalizedBolus.startTime, unfinalizedBolus.startTime)
        XCTAssertEqual(restoredUnfinalizedBolus.duration, unfinalizedBolus.duration)
        XCTAssertEqual(restoredUnfinalizedBolus.scheduledCertainty, unfinalizedBolus.scheduledCertainty)
        XCTAssertEqual(restoredUnfinalizedBolus.endTime, unfinalizedBolus.endTime)
        XCTAssertEqual(restoredUnfinalizedBolus.rate, unfinalizedBolus.rate)
    }
    
    func testRawValueTBRWithProgrammedRate() {
        let rate = 0.5
        let startTime = Date()
        let duration = TimeInterval.minutes(30)
        var unfinalizedTBR = UnfinalizedDose(tempBasalRate: rate,
                                             startTime: startTime,
                                             duration: duration,
                                             scheduledCertainty: .certain)
        unfinalizedTBR.programmedRate = rate
        let rawValue = unfinalizedTBR.rawValue
        XCTAssertEqual(UnfinalizedDose.DoseType(rawValue: rawValue["rawDoseType"] as! UnfinalizedDose.DoseType.RawValue), .tempBasal)
        XCTAssertEqual(rawValue["units"] as! Double, rate*duration.hours)
        XCTAssertEqual(rawValue["startTime"] as! Date, startTime)
        XCTAssertEqual(UnfinalizedDose.ScheduledCertainty(rawValue: rawValue["rawScheduledCertainty"] as! UnfinalizedDose.ScheduledCertainty.RawValue), .certain)
        XCTAssertNil(rawValue["programmedUnits"])
        XCTAssertEqual(rawValue["programmedRate"] as! Double, rate)
        XCTAssertEqual(rawValue["duration"] as! Double, duration)
        
        let restoredUnfinalizedTBR = UnfinalizedDose(rawValue: rawValue)!
        XCTAssertEqual(restoredUnfinalizedTBR.doseType, unfinalizedTBR.doseType)
        XCTAssertEqual(restoredUnfinalizedTBR.units, unfinalizedTBR.units)
        XCTAssertEqual(restoredUnfinalizedTBR.programmedUnits, unfinalizedTBR.programmedUnits)
        XCTAssertEqual(restoredUnfinalizedTBR.programmedRate, unfinalizedTBR.programmedRate)
        XCTAssertEqual(restoredUnfinalizedTBR.startTime, unfinalizedTBR.startTime)
        XCTAssertEqual(restoredUnfinalizedTBR.duration, unfinalizedTBR.duration)
        XCTAssertEqual(restoredUnfinalizedTBR.scheduledCertainty, unfinalizedTBR.scheduledCertainty)
        XCTAssertEqual(restoredUnfinalizedTBR.endTime, unfinalizedTBR.endTime)
        XCTAssertEqual(restoredUnfinalizedTBR.rate, unfinalizedTBR.rate)
    }
    
    func testRestoreFromRawValue() {
        let rate = 0.5
        let startTime = Date()
        let duration = TimeInterval.minutes(30)
        let expectedUnfinalizedTBR = UnfinalizedDose(tempBasalRate: rate,
                                                     startTime: startTime,
                                                     duration: duration,
                                                     scheduledCertainty: .certain)
        let rawValue = expectedUnfinalizedTBR.rawValue
        let unfinalizedTBR = UnfinalizedDose(rawValue: rawValue)!
        XCTAssertEqual(unfinalizedTBR.doseType, .tempBasal)
        XCTAssertEqual(unfinalizedTBR.units, rate*duration.hours)
        XCTAssertNil(unfinalizedTBR.programmedUnits)
        XCTAssertNil(unfinalizedTBR.programmedRate)
        XCTAssertEqual(unfinalizedTBR.startTime, startTime)
        XCTAssertEqual(unfinalizedTBR.duration, duration)
        XCTAssertEqual(unfinalizedTBR.scheduledCertainty, .certain)
        XCTAssertEqual(unfinalizedTBR.endTime, startTime.addingTimeInterval(duration))
        XCTAssertEqual(unfinalizedTBR.rate, rate)
    }
    
    func testDoseEntryInitFromUnfinalizedBolus() {
        let amount = 3.5
        let startTime = Date()
        let now = Date()
        let duration = TimeInterval(amount / Pod.bolusDeliveryRate)
        let unfinalizedBolus = UnfinalizedDose(bolusAmount: amount,
                                               startTime: startTime,
                                               scheduledCertainty: .certain)
        let doseEntry = DoseEntry(unfinalizedBolus, at: now)
        XCTAssertEqual(doseEntry.type, .bolus)
        XCTAssertEqual(doseEntry.startDate, startTime)
        XCTAssertEqual(doseEntry.endDate, startTime.addingTimeInterval(duration))
        XCTAssertEqual(doseEntry.programmedUnits, amount)
        XCTAssertEqual(doseEntry.unit, .units)
        XCTAssertNil(doseEntry.deliveredUnits)
    }
    
    func testDoseEntryInitFromUnfinalizedTBR() {
        let amount = 0.5
        let startTime = Date()
        let now = Date()
        let duration = TimeInterval.minutes(30)
        let rate = amount*duration.hours
        let unfinalizedTBR = UnfinalizedDose(tempBasalRate: amount,
                                               startTime: startTime,
                                               duration: duration,
                                               scheduledCertainty: .certain)
        let doseEntry = DoseEntry(unfinalizedTBR, at: now)
        XCTAssertEqual(doseEntry.type, .tempBasal)
        XCTAssertEqual(doseEntry.startDate, startTime)
        XCTAssertEqual(doseEntry.endDate, startTime.addingTimeInterval(duration))
        XCTAssertEqual(doseEntry.programmedUnits, rate)
        XCTAssertEqual(doseEntry.unit, .unitsPerHour)
        XCTAssertNil(doseEntry.deliveredUnits)
    }
    
    func testDoseEntryInitFromUnfinalizedSuspend() {
        let startTime = Date()
        let now = Date()
        let unfinalizedSuspend = UnfinalizedDose(suspendStartTime: startTime,
                                                 scheduledCertainty: .certain)
        let doseEntry = DoseEntry(unfinalizedSuspend, at: now)
        XCTAssertEqual(doseEntry.type, .suspend)
        XCTAssertEqual(doseEntry.startDate, startTime)
        XCTAssertEqual(doseEntry.endDate, startTime)
        XCTAssertEqual(doseEntry.programmedUnits, 0)
        XCTAssertEqual(doseEntry.unit, .units)
        XCTAssertNil(doseEntry.deliveredUnits)
    }
    
    func testDoseEntryInitFromUnfinalizedResume() {
        let startTime = Date()
        let now = Date()
        let unfinalizedResume = UnfinalizedDose(resumeStartTime: startTime,
                                                 scheduledCertainty: .certain)
        let doseEntry = DoseEntry(unfinalizedResume, at: now)
        XCTAssertEqual(doseEntry.type, .resume)
        XCTAssertEqual(doseEntry.startDate, startTime)
        XCTAssertEqual(doseEntry.endDate, startTime)
        XCTAssertEqual(doseEntry.programmedUnits, 0)
        XCTAssertEqual(doseEntry.unit, .units)
        XCTAssertNil(doseEntry.deliveredUnits)
    }
}
