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

        let basalScheduleItems = [RepeatingScheduleValue(startTime: 0, value: 1.0)]
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

        let startDate = Date()

        podStatusUpdateExpectation = expectation(description: "pod state updates")
        podStatusUpdateExpectation?.expectedFulfillmentCount = 2

        pumpManagerStatusUpdateExpectation = expectation(description: "pumpmanager status updates")
        pumpManagerStatusUpdateExpectation?.expectedFulfillmentCount = 2

        pumpManagerDelegateStateUpdateExpectation = expectation(description: "pumpmanager delegate state updates")
        pumpManagerDelegateStateUpdateExpectation?.expectedFulfillmentCount = 2

        // Set a new reservoir value to make sure the result of the set program is used (5U)
        mockPodCommManager.podStatus.reservoirUnitsRemaining = 500

        pumpManager.enactBolus(units: 1, at: startDate) { (result) in
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

        let startDate = Date()

        pumpManagerStatusUpdateExpectation = expectation(description: "pumpmanager status updates")
        pumpManagerStatusUpdateExpectation?.expectedFulfillmentCount = 2

        pumpManagerDelegateStateUpdateExpectation = expectation(description: "pumpmanager delegate state updates")
        pumpManagerDelegateStateUpdateExpectation?.expectedFulfillmentCount = 2

        mockPodCommManager.deliveryProgramError = .podNotAvailable

        pumpManager.enactBolus(units: 1, at: startDate) { (result) in
            bolusCallbacks.fulfill()
            switch result {
            case .success:
                XCTFail("Enact bolus with no pod should return error")
            case .failure(let error):
                switch error {
                case .communication:
                    break
                default:
                    XCTFail("Expected communication error")
                }
            }
        }
        waitForExpectations(timeout: 3)

        guard case .noBolus = pumpManager.status.bolusState else {
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
        pumpManagerDelegateStateUpdateExpectation?.assertForOverFulfill = false
//        pumpManagerDelegateStateUpdateExpectation?.expectedFulfillmentCount = 2

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
        
        timeTravel(.minutes(10))
        
        pumpEventStorageExpectation = expectation(description: "pumpmanager dose storage")
        // Sometimes, when a test is run in CI, this expectation is over-fulfilled.
        // When this happens, the test crashes.  This hopefully would at least avoid that crash.
        pumpEventStorageExpectation?.assertForOverFulfill = false
        //pumpEventStorageExpectation?.expectedFulfillmentCount = 2

        pumpManager.ensureCurrentPumpData(completion: nil)

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
        
        mockPodCommManager.deliveryProgramError = .podNotAvailable

        pumpManager.setBasalSchedule(dailyItems: items) { (error) in
            callbackExpectation.fulfill()
            guard let pumpManagerError = error as? DashPumpManagerError else {
                XCTFail("Unexpected error: \(String(describing: error))")
                return
            }
            guard case DashPumpManagerError.podCommError(.podNotAvailable) = pumpManagerError else {
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
        
        // PumpManager should indicate no delivery after pod is discarded
        XCTAssertNil(lastPumpManagerStatus.basalDeliveryState)
    }
    
    func testAlarmDuringBolusShouldUseRemainingInsulinField() {
        
        let bolusCallbacks = expectation(description: "bolus callbacks")

        pumpEventStorageExpectation = expectation(description: "pumpmanager stores bolus")

        pumpManager.enactBolus(units: 5, at: simulatedDate) { (result) in
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
    
    func testUnacknowledgedCommandOnBolusWasProgrammed() {
        mockPodCommManager.deliveryProgramError = .unacknowledgedCommandPendingRetry
        let bolusCompletion = expectation(description: "enactBolus completed")

        pumpManagerStatusUpdateExpectation = expectation(description: "pumpmanager status updates")
        pumpManagerStatusUpdateExpectation?.assertForOverFulfill = false

        pumpManager.enactBolus(units: 1, at: Date()) { (result) in
            switch result {
            case .failure(let error):
                switch error {
                case .uncertainDelivery:
                    break
                default:
                    XCTFail("Enact bolus should fail with uncertainDelivery error on unacknowledged command")
                }
            case .success:
                XCTFail("Enact bolus should not succeed when send program fails with unacknowledged command")
            }
            bolusCompletion.fulfill()
        }
        
        waitForExpectations(timeout: 3)

        XCTAssertEqual(0, reportedPumpEvents.count) // Should not have stored any doses yet

        XCTAssertEqual(true, pumpManagerStatusUpdates.last!.deliveryIsUncertain)
        
        // DashPumpManager should recover from uncertain state when bluetooth connection returns, and sdk returns PendingResult
        
        pumpEventStorageExpectation = expectation(description: "pumpmanager dose storage")
        pumpEventStorageExpectation?.assertForOverFulfill = false

        mockPodCommManager.unacknowledgedCommandRetryResult = PendingRetryResult.wasProgrammed
        
        pumpManager.podCommManager(mockPodCommManager, connectionStateDidChange: ConnectionState.connected)

        waitForExpectations(timeout: 3)

        XCTAssertEqual(1, reportedPumpEvents.count)
    }
    
    func testUnacknowledgedBolusWasNotProgrammed() {
        mockPodCommManager.deliveryProgramError = .unacknowledgedCommandPendingRetry
        let bolusCompletion = expectation(description: "enactBolus completed")

        pumpManager.enactBolus(units: 1, at: Date()) { (result) in
            switch result {
            case .failure(let error):
                switch error {
                case .uncertainDelivery:
                    break
                default:
                    XCTFail("Enact bolus should fail with uncertainDelivery error on unacknowledged command")
                }
            case .success:
                XCTFail("Enact bolus should not succeed when send program fails with unacknowledged command")
            }
            bolusCompletion.fulfill()
        }
        
        waitForExpectations(timeout: 3)

        XCTAssertEqual(0, reportedPumpEvents.count) // Should not have stored any doses yet

        // DashPumpManager should recover from uncertain state when bluetooth connection returns, and sdk returns PendingResult
        
        pumpEventStorageExpectation = expectation(description: "pumpmanager dose storage")
        pumpEventStorageExpectation?.assertForOverFulfill = false

        mockPodCommManager.unacknowledgedCommandRetryResult = PendingRetryResult.wasNotProgrammed
        
        pumpManager.podCommManager(mockPodCommManager, connectionStateDidChange: ConnectionState.connected)

        waitForExpectations(timeout: 3)

        XCTAssertEqual(0, reportedPumpEvents.count)
    }
    
    func testUnacknowledgedBolusResolvedWithUncertainty() {
        mockPodCommManager.deliveryProgramError = .unacknowledgedCommandPendingRetry
        let bolusCompletion = expectation(description: "enactBolus completed")
        
        pumpManager.enactBolus(units: 1, at: Date()) { (result) in
            switch result {
            case .failure(let error):
                switch error {
                case .uncertainDelivery:
                    break
                default:
                    XCTFail("Enact bolus should fail with uncertainDelivery error on unacknowledged command")
                }
            case .success:
                XCTFail("Enact bolus should not succeed when send program fails with unacknowledged command")
            }
            bolusCompletion.fulfill()
        }
        
        waitForExpectations(timeout: 3)

        XCTAssertEqual(0, reportedPumpEvents.count) // Should not have stored any doses yet

        pumpEventStorageExpectation = expectation(description: "pumpmanager dose storage")
        pumpEventStorageExpectation?.assertForOverFulfill = false

        mockPodCommManager.unacknowledgedCommandRetryResult = nil
        
        timeTravel(.minutes(2))
        
        let discardCompletion = expectation(description: "discardPod completed")

        pumpManager.discardPod { (_) in
            discardCompletion.fulfill()
        }

        waitForExpectations(timeout: 3)

        XCTAssertEqual(2, reportedPumpEvents.count) // The bolus and the discardPod suspend
        
        let bolus = reportedPumpEvents.first!
        
        XCTAssertEqual(.bolus, bolus.type)

        XCTAssertEqual(1, bolus.dose?.deliveredUnits)
    }

    func testUnacknowledgedHighTempBasalResolvedWithUncertainty() {
        mockPodCommManager.deliveryProgramError = .unacknowledgedCommandPendingRetry
        let tempBasalCompletion = expectation(description: "enactTempBasal completed")
        
        // scheduled basal rate is 1U/hr (see setUp())
        pumpManager.enactTempBasal(unitsPerHour: 3, for: .minutes(30)) { (result) in
            switch result {
            case .failure(let error):
                switch error {
                case .uncertainDelivery:
                    break
                default:
                    XCTFail("Enact tempBasal should fail with uncertainDelivery error on unacknowledged command")
                }
            case .success:
                XCTFail("Enact bolus should not succeed when send program fails with unacknowledged command")
            }
            tempBasalCompletion.fulfill()
        }
        
        waitForExpectations(timeout: 3)

        XCTAssertEqual(0, reportedPumpEvents.count) // Should not have stored any doses yet

        pumpEventStorageExpectation = expectation(description: "pumpmanager dose storage")
        pumpEventStorageExpectation?.assertForOverFulfill = false

        mockPodCommManager.unacknowledgedCommandRetryResult = nil
        
        timeTravel(.minutes(2))
        
        let discardCompletion = expectation(description: "discardPod completed")

        pumpManager.discardPod { (_) in
            discardCompletion.fulfill()
        }

        waitForExpectations(timeout: 3)

        XCTAssertEqual(2, reportedPumpEvents.count) // The high temp and the discardPod suspend
        
        let tempBasal = reportedPumpEvents.first!
        
        XCTAssertEqual(.tempBasal, tempBasal.type)

        XCTAssertEqual(TimeInterval(minutes: 2), tempBasal.dose!.endDate.timeIntervalSince(tempBasal.dose!.startDate))
    }
    
    func testUnacknowledgedLowTempBasalResolvedWithUncertainty() {
        mockPodCommManager.deliveryProgramError = .unacknowledgedCommandPendingRetry
        let tempBasalCompletion = expectation(description: "enactTempBasal completed")
        
        // scheduled basal rate is 1U/hr (see setUp())
        pumpManager.enactTempBasal(unitsPerHour: 0.5, for: .minutes(30)) { (result) in
            switch result {
            case .failure(let error):
                switch error {
                case .uncertainDelivery:
                    break
                default:
                    XCTFail("Enact tempBasal should fail with uncertainDelivery error on unacknowledged command")
                }
            case .success:
                XCTFail("Enact bolus should not succeed when send program fails with unacknowledged command")
            }
            tempBasalCompletion.fulfill()
        }
        
        waitForExpectations(timeout: 3)

        XCTAssertEqual(0, reportedPumpEvents.count) // Should not have stored any doses yet

        pumpEventStorageExpectation = expectation(description: "pumpmanager dose storage")
        pumpEventStorageExpectation?.assertForOverFulfill = false

        mockPodCommManager.unacknowledgedCommandRetryResult = nil
        
        timeTravel(.minutes(2))
        
        let discardCompletion = expectation(description: "discardPod completed")

        pumpManager.discardPod { (_) in
            discardCompletion.fulfill()
        }

        waitForExpectations(timeout: 3)

        // Should not include the low temp, we assume it failed on uncertainty
        XCTAssertEqual(1, reportedPumpEvents.count) // The discardPod suspend
        
        let suspend = reportedPumpEvents.first!
        
        XCTAssertEqual(.suspend, suspend.type)
    }
    
    func testUnacknowledgedResumeResolvedAsReceived() {
        let suspendCompletion = expectation(description: "suspend completed")
        pumpManager.suspendDelivery { (result) in
            suspendCompletion.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssert(pumpManager.status.basalDeliveryState!.isSuspended)

        mockPodCommManager.deliveryProgramError = .unacknowledgedCommandPendingRetry
        let resumeCompletion = expectation(description: "resume completed")
        
        pumpManager.resumeDelivery { (error) in
            XCTAssertNotNil(error)
            resumeCompletion.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(0, reportedPumpEvents.count) // Should not have stored any doses yet

        pumpEventStorageExpectation = expectation(description: "pumpmanager dose storage")
        pumpEventStorageExpectation?.assertForOverFulfill = false

        mockPodCommManager.unacknowledgedCommandRetryResult = PendingRetryResult.wasProgrammed
        
        pumpManager.podCommManager(mockPodCommManager, connectionStateDidChange: ConnectionState.connected)

        waitForExpectations(timeout: 3)
        
        XCTAssert(!pumpManager.status.basalDeliveryState!.isSuspended)
        
        let resume = reportedPumpEvents.last!
        
        XCTAssertEqual(.resume, resume.type)
    }
    
    func testEnsureCurrentPumpDataStale() {
        runTestEnsureCurrentPumpData(withTimeTravel: .minutes(10))
    }
    
    func testEnsureCurrentPumpDataNotStale() {
        runTestEnsureCurrentPumpData(withTimeTravel: 0.0)
    }
    
    private func runTestEnsureCurrentPumpData(withTimeTravel delay: TimeInterval) {
        timeTravel(0)
        let statusExpectation = expectation(description: "status")
        pumpManager.getPodStatus { _ in
            statusExpectation.fulfill()
        }
        wait(for: [statusExpectation], timeout: 1.0)

        timeTravel(delay)
        
        let ensureCurrentPumpDataCompletionCalledExpectation = expectation(description: "ensureCurrentPumpData calls completion")
        self.pumpManager.ensureCurrentPumpData {
            ensureCurrentPumpDataCompletionCalledExpectation.fulfill()
        }

        wait(for: [ensureCurrentPumpDataCompletionCalledExpectation], timeout: 1.0)
    }
    
    func testSyncBasalRateScheduleWhileSuspendedKeepsPodSuspended() {
        let suspendCompletion = expectation(description: "suspend completed")
        pumpManager.suspendDelivery { (error) in
            XCTAssertNil(error)
            suspendCompletion.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssert(pumpManager.status.basalDeliveryState!.isSuspended)
        
        let newBasalScheduleItems = [RepeatingScheduleValue(startTime: 0, value: 2.0)]

        let setBasalScheduleCompletion = expectation(description: "setBasalSchedule completed")
        pumpManager.syncBasalRateSchedule(items: newBasalScheduleItems) { (result) in
            if case .failure(let error) = result {
                XCTFail("syncBasalRateSchedule failed unexpectedly with error: \(error)")
            }
            setBasalScheduleCompletion.fulfill()
        }
        waitForExpectations(timeout: 3)
        
        XCTAssert(pumpManager.status.basalDeliveryState!.isSuspended)
        
        let resumeCompletion = expectation(description: "resume completed")
        pumpManager.resumeDelivery() { (error) in
            XCTAssertNil(error)
            resumeCompletion.fulfill()
        }
        waitForExpectations(timeout: 3)
        
        XCTAssertEqual(200, mockPodCommManager.lastBasalProgram?.basalSegments[0].basalRate)
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

    func pumpManager(_ pumpManager: PumpManager, didReadReservoirValue units: Double, at date: Date, completion: @escaping (Result<(newValue: ReservoirValue, lastValue: ReservoirValue?, areStoredValuesContinuous: Bool), Error>) -> Void) {
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
