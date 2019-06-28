//
//  DashKitTests.swift
//  DashKitTests
//
//  Created by Pete Schwamb on 4/18/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import XCTest
import PodSDK
@testable import DashKit

class DashKitTests: XCTestCase {

    func testBolus() {
        let podCommManager = MockPodCommManager()
        let basalProgram = try! BasalProgram(basalSegments: [BasalSegment(startTime: 0, endTime: 48, basalRate: 5)])
        let state = DashPumpManagerState(timeZone: TimeZone.currentFixed, basalProgram: basalProgram)
        let pumpManager = DashPumpManager(state: state, podCommManager: podCommManager)

        XCTAssertEqual(pumpManager.hasActivePod, false)

        let bolusCallbacks = expectation(description: "bolus callbacks")
        bolusCallbacks.expectedFulfillmentCount = 2

        let startDate = Date()

        pumpManager.enactBolus(units: 1, at: startDate, willRequest: { (dose) in
            bolusCallbacks.fulfill()
            XCTAssertEqual(startDate, dose.startDate)
        }) { (result) in
            bolusCallbacks.fulfill()
            switch result {
            case .failure(let error):
                XCTFail("enactBolus failed with error: \(error)")
            case .success(let dose):
                XCTAssertEqual(startDate, dose.startDate)
            }
        }

        waitForExpectations(timeout: 3)
    }

}
