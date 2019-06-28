//
//  DashKitTests.swift
//  DashKitTests
//
//  Created by Pete Schwamb on 4/18/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import XCTest
import PodSDK
import LoopKit
import UserNotifications
@testable import DashKit

class DashKitTests: XCTestCase {

    private var stateUpdates: [DashPumpManagerState] = []
    private var stateUpdateExpectation: XCTestExpectation?

    private var pumpManagerStatusUpdates: [PumpManagerStatus] = []
    private var pumpManagerStatusUpdateExpectation: XCTestExpectation?

    private var pumpManagerDelegateStateUpdateExpectation: XCTestExpectation?

    private var pumpManager: DashPumpManager!
    private var podCommManager: MockPodCommManager!

    override func setUp() {
        super.setUp()

        let basalProgram = try! BasalProgram(basalSegments: [BasalSegment(startTime: 0, endTime: 48, basalRate: 5)])
        var state = DashPumpManagerState(timeZone: TimeZone.currentFixed, basalProgram: basalProgram)
        state.podActivatedAt = Date().addingTimeInterval(.days(1))

        podCommManager = MockPodCommManager()
        pumpManager = DashPumpManager(state: state, podCommManager: podCommManager)
        pumpManager.addPodStatusObserver(self, queue: DispatchQueue.main)
        pumpManager.pumpManagerDelegate = self
    }

    override func tearDown() {
        super.tearDown()

        stateUpdates.removeAll()
        pumpManagerStatusUpdates.removeAll()
        stateUpdateExpectation = nil
        pumpManagerStatusUpdateExpectation = nil
        pumpManagerDelegateStateUpdateExpectation = nil
    }

    func testSuccessfulBolus() {

        XCTAssertEqual(pumpManager.hasActivePod, true)

        let bolusCallbacks = expectation(description: "bolus callbacks")
        bolusCallbacks.expectedFulfillmentCount = 2

        let startDate = Date()

        stateUpdateExpectation = expectation(description: "pod state updates")

        pumpManagerStatusUpdateExpectation = expectation(description: "pumpmanager status updates")
        pumpManagerStatusUpdateExpectation?.expectedFulfillmentCount = 2

        pumpManagerDelegateStateUpdateExpectation = expectation(description: "pumpmanager delegate state updates")
        pumpManagerDelegateStateUpdateExpectation?.expectedFulfillmentCount = 3

        // Set a new reservoir value to make sure the result of the set program is used (5U)
        podCommManager.podStatus.reservoirUnitsRemaining = 500

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
                XCTAssertEqual(100, self.podCommManager.lastBolusVolume)
            }
        }
        waitForExpectations(timeout: 3)

        XCTAssert(!stateUpdates.isEmpty)
        let lastState = stateUpdates.last!
        XCTAssertNil(lastState.bolusTransition)

        switch lastState.reservoirLevel {
        case .some(.valid(let value)):
            XCTAssertEqual(5.0, value, accuracy: 0.01)
        default:
            XCTFail("Expected reservoir value")
        }
    }
}

extension DashKitTests: PodStatusObserver {
    func didUpdatePodStatus() {
        stateUpdateExpectation?.fulfill()
        stateUpdates.append(pumpManager.state)
    }
}

extension DashKitTests: PumpManagerStatusObserver {
    func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus) {
        pumpManagerStatusUpdateExpectation?.fulfill()
        pumpManagerStatusUpdates.append(status)
    }
}

extension DashKitTests: PumpManagerDelegate {
    func pumpManagerBLEHeartbeatDidFire(_ pumpManager: PumpManager) {
    }

    func pumpManagerMustProvideBLEHeartbeat(_ pumpManager: PumpManager) -> Bool {
        return false
    }

    func pumpManagerWillDeactivate(_ pumpManager: PumpManager) {
    }

    func pumpManager(_ pumpManager: PumpManager, didUpdatePumpRecordsBasalProfileStartEvents pumpRecordsBasalProfileStartEvents: Bool) {
    }

    func pumpManager(_ pumpManager: PumpManager, didError error: PumpManagerError) {
    }

    func pumpManager(_ pumpManager: PumpManager, didReadPumpEvents events: [NewPumpEvent], completion: @escaping (Error?) -> Void) {
    }

    func pumpManager(_ pumpManager: PumpManager, didReadReservoirValue units: Double, at date: Date, completion: @escaping (PumpManagerResult<(newValue: ReservoirValue, lastValue: ReservoirValue?, areStoredValuesContinuous: Bool)>) -> Void) {
    }

    func pumpManager(_ pumpManager: PumpManager, didAdjustPumpClockBy adjustment: TimeInterval) {
    }

    func pumpManagerDidUpdateState(_ pumpManager: PumpManager) {
        pumpManagerDelegateStateUpdateExpectation?.fulfill()
    }

    func pumpManagerRecommendsLoop(_ pumpManager: PumpManager) {
    }

    func startDateToFilterNewPumpEvents(for manager: PumpManager) -> Date {
        return Date()
    }

    func scheduleNotification(for manager: DeviceManager, identifier: String, content: UNNotificationContent, trigger: UNNotificationTrigger?) {
    }

    func clearNotification(for manager: DeviceManager, identifier: String) {
    }
}
