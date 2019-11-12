//
//  UnfinalizedDoseTests.swift
//  DashKitTests
//
//  Created by Pete Schwamb on 11/11/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import XCTest
@testable import DashKit

class UnfinalizedDoseTests: XCTestCase {
    func testBolusCancelLongAfterFinishTime() {
        let start = Date()
        var dose = UnfinalizedDose(bolusAmount: 1, startTime: start, scheduledCertainty: .certain)
        dose.cancel(at: start + .hours(2))
        
        XCTAssertEqual(1.0, dose.units)
    }
}
