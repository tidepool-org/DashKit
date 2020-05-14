//
//  BasalProgramTests.swift
//  DashKitTests
//
//  Created by Pete Schwamb on 5/14/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import XCTest
import LoopKit
@testable import DashKit
import PodSDK

class BasalProgramTests: XCTestCase {
    
    func testCurrentRate() {
    
        let program = BasalProgram(items: [RepeatingScheduleValue(startTime: 0, value: 10.0), RepeatingScheduleValue(startTime: .hours(12), value: 15.0)])!
        
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .currentFixed
        let midnight = calendar.startOfDay(for: Date())
        
        XCTAssertEqual(10, program.currentRate(using: calendar, at: midnight.addingTimeInterval(.hours(0))).basalRateUnitsPerHour)
        XCTAssertEqual(10, program.currentRate(using: calendar, at: midnight.addingTimeInterval(.hours(0.25))).basalRateUnitsPerHour)
        XCTAssertEqual(15, program.currentRate(using: calendar, at: midnight.addingTimeInterval(.hours(12))).basalRateUnitsPerHour)
        XCTAssertEqual(15, program.currentRate(using: calendar, at: midnight.addingTimeInterval(.hours(23.75))).basalRateUnitsPerHour)
    }
}
