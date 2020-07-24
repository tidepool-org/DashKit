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
import PodSDK

class DashPumpManagerTests: XCTestCase {

    private var posStatusUpdates: [DashPumpManagerState] = []
    private var podStatusUpdateExpectation: XCTestExpectation?

    private var pumpManagerStatusUpdates: [PumpManagerStatus] = []
    private var pumpManagerStatusUpdateExpectation: XCTestExpectation?

    private var pumpManagerDelegateStateUpdateExpectation: XCTestExpectation?

    private var reportedPumpEvents: [NewPumpEvent] = []
    private var pumpEventStorageExpectation: XCTestExpectation?

    private var pumpManager: DashPumpManager!
    private var mockPodCommManager: MockPodCommManager!
    
    private var alertsIssued: [Alert] = []
    private var pumpManagerAlertIssuanceExpectation: XCTestExpectation?
    
    private var alertsRetracted: [Alert.Identifier] = []
    private var pumpManagerAlertRetractionExpectation: XCTestExpectation?

    // Date simulation
    private var dateFormatter = ISO8601DateFormatter()
    private var simulatedDate: Date = ISO8601DateFormatter().date(from: "2019-10-02T00:00:00Z")!
    private var dateSimulationOffset: TimeInterval = 0
    
    private func setSimulatedDate(from dateString: String) {
        simulatedDate = dateFormatter.date(from: dateString)!
        dateSimulationOffset = 0
    }
    
    private func timeTravel(_ time: TimeInterval) {
        dateSimulationOffset += time
    }
    
    private func dateGenerator() -> Date {
        return self.simulatedDate + dateSimulationOffset
    }

    override func setUp() {
        super.setUp()

        let basalScheduleItems = [RepeatingScheduleValue(startTime: 0, value: 5.0)]
        let schedule = BasalRateSchedule(dailyItems: basalScheduleItems, timeZone: .current)!
        var state = DashPumpManagerState(basalRateSchedule: schedule, maximumTempBasalRate: 3.0, dateGenerator: dateGenerator)!
        state.podActivatedAt = Date().addingTimeInterval(.days(1))

        mockPodCommManager = MockPodCommManager()
        
        pumpManager = DashPumpManager(state: state, podCommManager: mockPodCommManager, dateGenerator: dateGenerator)
        pumpManager.addPodStatusObserver(self, queue: DispatchQueue.main)
        pumpManager.pumpManagerDelegate = self
    }

    override func tearDown() {
        super.tearDown()

        posStatusUpdates.removeAll()
        podStatusUpdateExpectation = nil

        pumpManagerStatusUpdates.removeAll()
        pumpManagerStatusUpdateExpectation = nil

        pumpManagerDelegateStateUpdateExpectation = nil

        reportedPumpEvents.removeAll()
        pumpEventStorageExpectation = nil
    }
    
    
    private func enactTempBasal(unitsPerHour: Double, duration: TimeInterval = .minutes(30)) {
        let tempBasalCallbackExpectation = expectation(description: "temp basal callback")
        pumpManager.enactTempBasal(unitsPerHour: unitsPerHour, for:duration) { (result) in
            tempBasalCallbackExpectation.fulfill()
        }
        waitForExpectations(timeout: 3)
    }


    func testSuccessfulBolus() {

        XCTAssertEqual(pumpManager.hasActivePod, true)

        let bolusCallbacks = expectation(description: "bolus callbacks")
        bolusCallbacks.expectedFulfillmentCount = 2

        let startDate = Date()

        podStatusUpdateExpectation = expectation(description: "pod state updates")
        podStatusUpdateExpectation?.expectedFulfillmentCount = 2

        pumpManagerStatusUpdateExpectation = expectation(description: "pumpmanager status updates")
        pumpManagerStatusUpdateExpectation?.expectedFulfillmentCount = 2

        pumpManagerDelegateStateUpdateExpectation = expectation(description: "pumpmanager delegate state updates")
        pumpManagerDelegateStateUpdateExpectation?.expectedFulfillmentCount = 2

        // Set a new reservoir value to make sure the result of the set program is used (5U)
        mockPodCommManager.podStatus.reservoirUnitsRemaining = 500

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
                XCTAssertEqual(100, self.mockPodCommManager.lastBolusVolume)
            }
        }
        waitForExpectations(timeout: 3)

        guard case .inProgress(let dose) = pumpManager.status.bolusState else {
            XCTFail("Expected bolus in progress")
            return
        }

        XCTAssertEqual(1, dose.programmedUnits)
        XCTAssertEqual(startDate, dose.startDate)

        XCTAssert(!posStatusUpdates.isEmpty)
        let lastState = posStatusUpdates.last!
        XCTAssertEqual(nil, lastState.activeTransition)

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

        mockPodCommManager.sendProgramFailureError = .podNotAvailable

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

        // External status updates
        pumpManagerStatusUpdateExpectation = expectation(description: "pumpmanager status updates")
        pumpManagerStatusUpdateExpectation?.expectedFulfillmentCount = 2

        // Persistence updates
        pumpManagerDelegateStateUpdateExpectation = expectation(description: "pumpmanager delegate state updates")
        pumpManagerDelegateStateUpdateExpectation?.expectedFulfillmentCount = 2

        // Set a new reservoir value to make sure the result of the set program is used (5U)
        mockPodCommManager.podStatus.reservoirUnitsRemaining = 500

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

        XCTAssert(!posStatusUpdates.isEmpty)
        let lastStatus = posStatusUpdates.last!

        switch lastStatus.reservoirLevel {
        case .some(.valid(let value)):
            XCTAssertEqual(5.0, value, accuracy: 0.01)
        default:
            XCTFail("Expected reservoir value")
        }
        
        pumpEventStorageExpectation = expectation(description: "pumpmanager dose storage")
        // Sometimes, when a test is run in CI, this expectation is over-fulfilled.
        // When this happens, the test crashes.  This hopefully would at least avoid that crash.
        pumpEventStorageExpectation?.assertForOverFulfill = false
        //pumpEventStorageExpectation?.expectedFulfillmentCount = 2

        pumpManager.assertCurrentPumpData()

        waitForExpectations(timeout: 3)

        XCTAssertEqual(2, reportedPumpEvents.count)

        let tempBasalEvent = reportedPumpEvents.last!
        XCTAssertEqual(1.0, tempBasalEvent.dose?.unitsPerHour)
        XCTAssertNil(tempBasalEvent.dose!.deliveredUnits)
        XCTAssertEqual(PumpEventType.tempBasal, tempBasalEvent.type)
    }

    func testFailedTempBasal() {
        XCTAssertEqual(pumpManager.hasActivePod, true)

        let tempBasalCallbackExpectation = expectation(description: "temp basal callbacks")

        pumpManager.enactTempBasal(unitsPerHour: 1, for: .minutes(30)) { (result) in
            tempBasalCallbackExpectation.fulfill()
        }
        XCTAssertEqual(0, reportedPumpEvents.count)
        waitForExpectations(timeout: 3)
    }
    
    func testSuccessfulSetBasalSchedule() {
        let callbackExpectation = expectation(description: "set basal scheduled callback")
        let items = [RepeatingScheduleValue(startTime: 0, value: 10.0), RepeatingScheduleValue(startTime: .hours(12), value: 15.0)]
        pumpManager.setBasalSchedule(dailyItems: items) { (error) in
            callbackExpectation.fulfill()
            guard error == nil else {
                XCTFail("Unexpected error: \(String(describing: error))")
                return
            }
        }
        waitForExpectations(timeout: 3)
        
        let program = BasalProgram(items: items)
        
        XCTAssertEqual(mockPodCommManager.lastBasalProgram, program)
        XCTAssertEqual(pumpManager.state.basalProgram, program)
    }

    func testFailedSetBasalSchedule() {
        let callbackExpectation = expectation(description: "set basal scheduled callback")
        let items = [RepeatingScheduleValue(startTime: 0, value: 10.0), RepeatingScheduleValue(startTime: .hours(12), value: 15.0)]
        
        mockPodCommManager.sendProgramFailureError = .podNotAvailable

        pumpManager.setBasalSchedule(dailyItems: items) { (error) in
            callbackExpectation.fulfill()
            guard let pumpManagerError = error as? DashPumpManagerError else {
                XCTFail("Unexpected error: \(String(describing: error))")
                return
            }
            guard case DashPumpManagerError.podCommError(description: "podNotAvailable") = pumpManagerError else {
                XCTFail("Expected podNotAvailable error")
                return
            }
        }
        waitForExpectations(timeout: 3)
        
        let program = BasalProgram(items: items)
        
        XCTAssertNotEqual(mockPodCommManager.lastBasalProgram, program)
        XCTAssertNotEqual(pumpManager.state.basalProgram, program)
    }

    func testDiscardPodShouldFinishPendingDoses() {
        
        enactTempBasal(unitsPerHour: 1)
        timeTravel(.minutes(5))
        let discardPodCallbackExpectation = expectation(description: "temp basal callbacks")
        pumpManager.discardPod { (result) in
            discardPodCallbackExpectation.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(3, reportedPumpEvents.count)
        let finalReportedTemp = reportedPumpEvents[1]
        XCTAssertEqual(false, finalReportedTemp.isMutable)
        XCTAssertEqual(0.05, finalReportedTemp.dose?.deliveredUnits)
        
        let finalSuspend = reportedPumpEvents.last!
        XCTAssertEqual(false, finalSuspend.isMutable)
        XCTAssertEqual(.suspend, finalSuspend.type)

        let lastPumpManagerStatus = pumpManagerStatusUpdates.last!
        if case .suspended(let date) = lastPumpManagerStatus.basalDeliveryState {
            XCTAssertEqual(dateGenerator(), date)
        } else {
            XCTFail("PumpManager should indicate suspended delivery after pod discarded")
        }
    }
    
    func testAlarmDuringBolusShouldUseRemainingInsulinField() {
        
        let bolusCallbacks = expectation(description: "bolus callbacks")
        bolusCallbacks.expectedFulfillmentCount = 2

        pumpEventStorageExpectation = expectation(description: "pumpmanager stores bolus")

        pumpManager.enactBolus(units: 5, at: simulatedDate, willRequest: { (dose) in
            bolusCallbacks.fulfill()
        }) { (result) in
            bolusCallbacks.fulfill()
        }

        waitForExpectations(timeout: 3)
        
        timeTravel(30)

        var podStatus = mockPodCommManager.podStatus
        podStatus.bolusUnitsRemaining = 2 * Int(Pod.podSDKInsulinMultiplier)
        
        let alarm = MockPodAlarm(
            alarmCode: AlarmCode.occlusion,
            alarmDescription: "Occlusion",
            podStatus: podStatus,
            occlusionType: .stallDuringRuntime,
            didErrorOccuredFetchingBolusInfo: false,
            wasBolusActiveWhenPodAlarmed: true,
            podStateWhenPodAlarmed: podStatus.podState,
            alarmTime: simulatedDate.advanced(by: 29),
            activationTime: podStatus.activationTime,
            referenceCode: "1234")

        pumpEventStorageExpectation = expectation(description: "pumpmanager stores interrupted bolus")

        pumpManager.podCommManager(mockPodCommManager!, didAlarm: alarm)

        waitForExpectations(timeout: 3)

        XCTAssertEqual(2, reportedPumpEvents.count)
        
        let bolusInProgress = reportedPumpEvents[0]
        XCTAssertEqual(5, bolusInProgress.dose!.programmedUnits)
        XCTAssertNil(bolusInProgress.dose!.deliveredUnits)
        
        let interruptedBolus = reportedPumpEvents[1]
        XCTAssertEqual(5, interruptedBolus.dose!.programmedUnits)
        XCTAssertEqual(3, interruptedBolus.dose!.deliveredUnits)
    }
    
    func testAlertIssuanceAndAcknowledgement() {
        let suspendEndedAlert = PodAlerts.podExpiring
        
        pumpManagerAlertIssuanceExpectation = expectation(description: "DashPumpManager should issue alert")
        
        
        pumpManager.podCommManagerHasAlerts(suspendEndedAlert)

        waitForExpectations(timeout: 3)

        XCTAssert(!alertsIssued.isEmpty)
        
        let issuedAlert = alertsIssued.last!
        
        pumpManager.acknowledgeAlert(alertIdentifier: issuedAlert.identifier.alertIdentifier)
        
        XCTAssert(!mockPodCommManager.silencedAlerts.isEmpty)
    }

    func testAlertIssuanceAndRetraction() {
        let suspendEndedAlert = PodAlerts.suspendEnded
        
        pumpManagerAlertIssuanceExpectation = expectation(description: "DashPumpManager should issue alert")
        pumpManagerAlertIssuanceExpectation?.expectedFulfillmentCount = 2 // One for the current alert, one for recurring.
        
        pumpManager.podCommManagerHasAlerts(suspendEndedAlert)

        waitForExpectations(timeout: 3)
        
        pumpManagerAlertIssuanceExpectation = nil

        XCTAssertEqual(2, alertsIssued.count)
        
        let issuedAlert = alertsIssued.first!
        
        pumpManagerAlertRetractionExpectation = expectation(description: "DashPumpManager should retract alert")
        pumpManagerAlertRetractionExpectation?.expectedFulfillmentCount = 2 // One for the current alert, one for recurring.

        pumpManager.podCommManagerHasAlerts([])

        waitForExpectations(timeout: 3)

        XCTAssertEqual(2, alertsRetracted.count)

        let retractedAlert = alertsRetracted.first!
        
        XCTAssertEqual(issuedAlert.identifier, retractedAlert)
    }    
}

extension DashPumpManagerTests: PodStatusObserver {
    func didUpdatePodStatus() {
        podStatusUpdateExpectation?.fulfill()
        posStatusUpdates.append(pumpManager.state)
    }
}

extension DashPumpManagerTests: PumpManagerStatusObserver {
    func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus) {
        pumpManagerStatusUpdateExpectation?.fulfill()
        pumpManagerStatusUpdates.append(status)
    }
}

extension DashPumpManagerTests: PumpManagerDelegate {
        
    func issueAlert(_ alert: Alert) {
        pumpManagerAlertIssuanceExpectation?.fulfill()
        alertsIssued.append(alert)
    }
    
    func retractAlert(identifier: Alert.Identifier) {
        pumpManagerAlertRetractionExpectation?.fulfill()
        alertsRetracted.append(identifier)
    }
    
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
        reportedPumpEvents.append(contentsOf: events)
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
    
    func removeNotificationRequests(for manager: DeviceManager, identifiers: [String]) {
    }

    func clearNotification(for manager: DeviceManager, identifier: String) {
    }
        
    func deviceManager(_ manager: DeviceManager, logEventForDeviceIdentifier deviceIdentifier: String?, type: DeviceLogEntryType, message: String, completion: ((Error?) -> Void)?) {
    }
}
