//
//  DashSettingsViewModelTests.swift
//  DashKitUITests
//
//  Created by Pete Schwamb on 7/21/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import XCTest
import DashKit
import PodSDK
import LoopKit
@testable import DashKitUI

class DashSettingsViewModelTests: XCTestCase {
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    private var simulatedDate: Date = ISO8601DateFormatter().date(from: "2019-10-02T00:00:00Z")!
    private var dateSimulationOffset: TimeInterval = 0
    
    private func dateGenerator() -> Date {
        return self.simulatedDate + dateSimulationOffset
    }

    func testBasalDeliveryRateWithScheduledBasal() {
        let basalScheduleItems = [RepeatingScheduleValue(startTime: 0, value: 1.0)]
        let schedule = BasalRateSchedule(dailyItems: basalScheduleItems, timeZone: .current)!
        let state = DashPumpManagerState(basalRateSchedule: schedule, lastPodCommState: .active, dateGenerator: dateGenerator)!

        let mockPodCommManager = MockPodCommManager()
        mockPodCommManager.simulatedCommsDelay = TimeInterval(0)
        let pumpManager = DashPumpManager(state: state, podCommManager: mockPodCommManager, dateGenerator: dateGenerator)
        let viewModel = DashSettingsViewModel(pumpManager: pumpManager)
        
        
        XCTAssertNotNil(viewModel.basalDeliveryRate)
        
        let basalDeliveryRate = viewModel.basalDeliveryRate!
        
        XCTAssertEqual(1.0, basalDeliveryRate)
    }

    func testBasalDeliveryRateWithSuspendedBasal() {
        let basalScheduleItems = [RepeatingScheduleValue(startTime: 0, value: 1.0)]
        let schedule = BasalRateSchedule(dailyItems: basalScheduleItems, timeZone: .current)!
        var state = DashPumpManagerState(basalRateSchedule: schedule, lastPodCommState: .active, dateGenerator: dateGenerator)!
        state.suspendState = .suspended(dateGenerator() - .hours(1))

        let mockPodCommManager = MockPodCommManager()
        mockPodCommManager.simulatedCommsDelay = TimeInterval(0)
        let pumpManager = DashPumpManager(state: state, podCommManager: mockPodCommManager, dateGenerator: dateGenerator)
        let viewModel = DashSettingsViewModel(pumpManager: pumpManager)
        
        
        XCTAssertNil(viewModel.basalDeliveryRate)
    }

    func testBasalDeliveryRateWithHighTemp() {
        let basalScheduleItems = [RepeatingScheduleValue(startTime: 0, value: 1.0)]
        let schedule = BasalRateSchedule(dailyItems: basalScheduleItems, timeZone: .current)!
        var state = DashPumpManagerState(basalRateSchedule: schedule, lastPodCommState: .active, dateGenerator: dateGenerator)!
        state.unfinalizedTempBasal = UnfinalizedDose(tempBasalRate: 2.0, startTime: dateGenerator() - .minutes(5), duration: .minutes(30), scheduledCertainty: .certain)

        let mockPodCommManager = MockPodCommManager()
        mockPodCommManager.simulatedCommsDelay = TimeInterval(0)
        let pumpManager = DashPumpManager(state: state, podCommManager: mockPodCommManager, dateGenerator: dateGenerator)
        let viewModel = DashSettingsViewModel(pumpManager: pumpManager)
        
        
        XCTAssertNotNil(viewModel.basalDeliveryRate)
        
        let basalDeliveryRate = viewModel.basalDeliveryRate!
        
        XCTAssertEqual(2, basalDeliveryRate)
    }
    
    func testBasalDeliveryRateWithLowTemp() {
        let basalScheduleItems = [RepeatingScheduleValue(startTime: 0, value: 1.0)]
        let schedule = BasalRateSchedule(dailyItems: basalScheduleItems, timeZone: .current)!
        var state = DashPumpManagerState(basalRateSchedule: schedule, lastPodCommState: .active, dateGenerator: dateGenerator)!
        state.unfinalizedTempBasal = UnfinalizedDose(tempBasalRate: 0.5, startTime: dateGenerator() - .minutes(5), duration: .minutes(30), scheduledCertainty: .certain)

        let mockPodCommManager = MockPodCommManager()
        mockPodCommManager.simulatedCommsDelay = TimeInterval(0)
        let pumpManager = DashPumpManager(state: state, podCommManager: mockPodCommManager, dateGenerator: dateGenerator)
        let viewModel = DashSettingsViewModel(pumpManager: pumpManager)
        
        
        XCTAssertNotNil(viewModel.basalDeliveryRate)
        
        let basalDeliveryRate = viewModel.basalDeliveryRate!
        
        XCTAssertEqual(0.5, basalDeliveryRate)
    }


}
