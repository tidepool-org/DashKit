//
//  DashPumpManagerTests.swift
//  DashPumpManagerTests
//
//  Created by Pete Schwamb on 4/18/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import XCTest
import LoopKit
import UserNotifications
@testable import DashKit

class DashPumpManagerTests: XCTestCase {

    private var stateUpdates: [DashPumpManagerState] = []
    private var stateUpdateExpectation: XCTestExpectation?

    private var pumpManagerStatusUpdates: [PumpManagerStatus] = []
    private var pumpManagerStatusUpdateExpectation: XCTestExpectation?

    private var pumpManagerDelegateStateUpdateExpectation: XCTestExpectation?

    private var lastPumpEvents: [NewPumpEvent] = []
    private var pumpEventStorageExpectation: XCTestExpectation?


    private var pumpManager: DashPumpManager!
    private var podCommManager: MockPodCommManager!

    override func setUp() {
        super.setUp()

        let basalScheduleItems = [RepeatingScheduleValue(startTime: 0, value: 5.0)]
        let schedule = BasalRateSchedule(dailyItems: basalScheduleItems, timeZone: .current)!
        var state = DashPumpManagerState(basalRateSchedule: schedule)!
        state.podActivatedAt = Date().addingTimeInterval(.days(1))

        podCommManager = MockPodCommManager()
        pumpManager = DashPumpManager(state: state, podCommManager: podCommManager)
        pumpManager.addPodStatusObserver(self, queue: DispatchQueue.main)
        pumpManager.pumpManagerDelegate = self
    }

    override func tearDown() {
        super.tearDown()

        stateUpdates.removeAll()
        stateUpdateExpectation = nil

        pumpManagerStatusUpdates.removeAll()
        pumpManagerStatusUpdateExpectation = nil

        pumpManagerDelegateStateUpdateExpectation = nil

        lastPumpEvents.removeAll()
        pumpEventStorageExpectation = nil
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
                XCTAssertEqual(DoseType.bolus, dose.type)
                XCTAssertEqual(DoseUnit.units, dose.unit)
                XCTAssertEqual(1.0, dose.programmedUnits)
                XCTAssertEqual(100, self.podCommManager.lastBolusVolume)
            }
        }
        waitForExpectations(timeout: 3)

        guard case .inProgress(let dose) = pumpManager.status.bolusState else {
            XCTFail("Expected bolus in progress")
            return
        }

        XCTAssertEqual(1, dose.programmedUnits)
        XCTAssertEqual(startDate, dose.startDate)

        XCTAssert(!stateUpdates.isEmpty)
        let lastState = stateUpdates.last!
        XCTAssertEqual(.stable, lastState.bolusEngageState)

        switch lastState.reservoirLevel {
        case .some(.valid(let value)):
            XCTAssertEqual(5.0, value, accuracy: 0.01)
        default:
            XCTFail("Expected reservoir value")
        }
    }

    func testFailedBolus() {

        XCTAssertEqual(pumpManager.hasActivePod, true)

        let bolusCallbacks = expectation(description: "bolus callbacks")
        bolusCallbacks.expectedFulfillmentCount = 2

        let startDate = Date()

        pumpManagerStatusUpdateExpectation = expectation(description: "pumpmanager status updates")
        pumpManagerStatusUpdateExpectation?.expectedFulfillmentCount = 2

        pumpManagerDelegateStateUpdateExpectation = expectation(description: "pumpmanager delegate state updates")
        pumpManagerDelegateStateUpdateExpectation?.expectedFulfillmentCount = 2

        podCommManager.sendProgramFailureError = .podNotAvailable

        pumpManager.enactBolus(units: 1, at: startDate, willRequest: { (dose) in
            bolusCallbacks.fulfill()
            XCTAssertEqual(startDate, dose.startDate)
        }) { (result) in
            bolusCallbacks.fulfill()
            guard case .failure(DashPumpManagerError.podCommError(description: "podNotAvailable")) = result else {
                XCTFail("Expected podNotAvailable error")
                return
            }
        }
        waitForExpectations(timeout: 3)

        guard case .none = pumpManager.status.bolusState else {
            XCTFail("Expected no bolus in progress")
            return
        }
    }

    func testSuccessfulTempBasal() {
        XCTAssertEqual(pumpManager.hasActivePod, true)

        let tempBasalCallbackExpectation = expectation(description: "temp basal callbacks")

        stateUpdateExpectation = expectation(description: "pod state updates")

        pumpManagerDelegateStateUpdateExpectation = expectation(description: "pumpmanager delegate state updates")
        pumpManagerDelegateStateUpdateExpectation?.expectedFulfillmentCount = 3

        // Set a new reservoir value to make sure the result of the set program is used (5U)
        podCommManager.podStatus.reservoirUnitsRemaining = 500

        pumpManager.enactTempBasal(unitsPerHour: 1, for: .minutes(30)) { (result) in
            tempBasalCallbackExpectation.fulfill()
            switch result {
            case .failure(let error):
                XCTFail("enactTempBasal failed with error: \(error)")
            case .success(let dose):
                XCTAssertEqual(DoseType.tempBasal, dose.type)
                XCTAssertEqual(DoseUnit.unitsPerHour, dose.unit)
                XCTAssertEqual(1.0, dose.unitsPerHour)
            }
        }
        waitForExpectations(timeout: 3)

        XCTAssert(!stateUpdates.isEmpty)
        let lastState = stateUpdates.last!

        switch lastState.reservoirLevel {
        case .some(.valid(let value)):
            XCTAssertEqual(5.0, value, accuracy: 0.01)
        default:
            XCTFail("Expected reservoir value")
        }

        pumpEventStorageExpectation = expectation(description: "pumpmanager dose storage")

        pumpManager.assertCurrentPumpData()

        waitForExpectations(timeout: 3)

        XCTAssertEqual(1, lastPumpEvents.count)

        let tempBasalEvent = lastPumpEvents.last!
        XCTAssertEqual(1.0, tempBasalEvent.dose?.unitsPerHour)
        XCTAssertEqual(PumpEventType.tempBasal, tempBasalEvent.type)
    }

    func testFailedTempBasal() {
        XCTAssertEqual(pumpManager.hasActivePod, true)

        let tempBasalCallbackExpectation = expectation(description: "temp basal callbacks")

        podCommManager.sendProgramFailureError = .podNotAvailable

        pumpManager.enactTempBasal(unitsPerHour: 1, for: .minutes(30)) { (result) in
            tempBasalCallbackExpectation.fulfill()
            guard case .failure(DashPumpManagerError.podCommError(description: "podNotAvailable")) = result else {
                XCTFail("Expected podNotAvailable error")
                return
            }
        }
        waitForExpectations(timeout: 3)
    }

}

extension DashPumpManagerTests: PodStatusObserver {
    func didUpdatePodStatus() {
        stateUpdateExpectation?.fulfill()
        stateUpdates.append(pumpManager.state)
    }
}

extension DashPumpManagerTests: PumpManagerStatusObserver {
    func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus) {
        pumpManagerStatusUpdateExpectation?.fulfill()
        pumpManagerStatusUpdates.append(status)
    }
}

extension DashPumpManagerTests: PumpManagerDelegate {

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

    func pumpManager(_ pumpManager: PumpManager, hasNewPumpEvents events: [NewPumpEvent], lastReconciliation: Date?, completion: @escaping (Error?) -> Void) {
        pumpEventStorageExpectation?.fulfill()
        lastPumpEvents = events
        completion(nil)
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
