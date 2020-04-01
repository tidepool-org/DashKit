//
//  MockPodCommManager.swift
//  DashKitTests
//
//  Created by Pete Schwamb on 6/27/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import DashKit
import PodSDK

struct MockPodStatus: PodStatus {
    var expirationDate: Date

    var podState: PodState

    var programStatus: ProgramStatus

    var activeAlerts: PodAlerts

    var isOcclusionAlertActive: Bool

    var bolusUnitsRemaining: Int

    var totalUnitsDelivered: Int

    var reservoirUnitsRemaining: Int

    var timeElapsedSinceActivation: TimeInterval

    var activationTime: Date

    func hasAlerts() -> Bool {
        return !activeAlerts.isEmpty
    }
    
    static func normalPodStatus() -> MockPodStatus {
        let activation = Date().addingTimeInterval(.hours(-2))
        return MockPodStatus(
            expirationDate: activation + TimeInterval(days: 3),
            podState: .runningAboveMinVolume,
            programStatus: .basalRunning,
            activeAlerts: PodAlerts([]),
            isOcclusionAlertActive: false,
            bolusUnitsRemaining: 0,
            totalUnitsDelivered: 38,
            reservoirUnitsRemaining: 1023,
            timeElapsedSinceActivation: 2,
            activationTime: activation)
    }
}

class MockPodCommManager: PodCommManagerProtocol {

    func updateBeepOptions(bolusReminder: BeepOption, tempBasalReminder: BeepOption, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(podStatus))
    }
    
    func verifyUnacknowledgedCommand(withRetry: Bool, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(podStatus))
    }
    
    func configPeriodicStatusCheck(interval: TimeInterval, completion: @escaping (PodCommResult<Bool>) -> ()) {
        completion(.success(true))
    }
    
    func disablePeriodicStatusCheck(completion: @escaping (PodCommResult<Bool>) -> ()) {
        completion(.success(true))
    }
    
    var lastBolusVolume: Int?
    var lastBasalProgram: BasalProgram?
    var lastTempBasal: TempBasal?

    var podStatus: MockPodStatus

    var sendProgramFailureError: PodCommError?

    var delegate: PodCommManagerDelegate?

    func setLogger(logger: LoggingProtocol) { }

    func setup(withLaunchingOptions launchOptions: [AnyHashable : Any]?) { }
    
    func startPodActivation(lowReservoirAlert: LowReservoirAlert?, podExpirationAlert: PodExpirationAlert?, eventListener: @escaping (ActivationStatus<ActivationStep1Event>) -> ()) {
        return
    }
    
    func finishPodActivation(basalProgram: ProgramType, autoOffAlert: AutoOffAlert?, eventListener: @escaping (ActivationStatus<ActivationStep2Event>) -> ()) {
        return
    }

    func discardPod(completion: @escaping (PodCommResult<Bool>) -> ()) {
        completion(.success(true))
    }

    func deactivatePod(completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(podStatus))
    }

    func getPodStatus(userInitiated: Bool, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(podStatus))
    }

    func getAlertsDetails(completion: @escaping (PodCommResult<PodAlerts>) -> ()) {
        completion(.success(PodAlerts(rawValue: 0)))
    }

    func playTestBeeps(completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(podStatus))
    }

    func sendProgram(programType: ProgramType, beepOption: BeepOption?, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        if let error = sendProgramFailureError {
            completion(.failure(error))
        } else {
            switch programType {
            case .basalProgram(let program, _):
                lastBasalProgram = program
            case .bolus(let bolus):
                lastBolusVolume = bolus.immediateVolume
            case .tempBasal(let tempBasal):
                lastTempBasal = tempBasal
            }
            completion(.success(podStatus))
        }
    }

    func stopProgram(programType: StopProgramType, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(MockPodStatus.normalPodStatus()))
    }

    func updateAlertSetting(alertSetting: PodAlertSetting, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(MockPodStatus.normalPodStatus()))
    }

    func silenceAlerts(alert: PodAlerts, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(MockPodStatus.normalPodStatus()))
    }

    func retryUnacknowledgedCommand(completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(MockPodStatus.normalPodStatus()))
    }

    func queryAndClearUnacknowledgedCommand(completion: @escaping (PodCommResult<PendingRetryResult>) -> ()) { }

    func getPodId() -> String? {
        return "MockPodID"
    }

    func getEstimatedBolusDeliveryTime() -> TimeInterval? {
        return nil
    }

    func getEstimatedBolusRemaining() -> Int {
        return 0
    }

    var podCommState: PodCommState {
        return .activating
    }

    init(podStatus: MockPodStatus? = nil) {
        if let podStatus = podStatus {
            self.podStatus = podStatus
        } else {
            let activation = Date()
            self.podStatus = MockPodStatus(
                expirationDate: activation + TimeInterval(days: 3),
                podState: .runningAboveMinVolume,
                programStatus: .basalRunning,
                activeAlerts: PodAlerts([]),
                isOcclusionAlertActive: false,
                bolusUnitsRemaining: 0,
                totalUnitsDelivered: 38,
                reservoirUnitsRemaining: 1023,
                timeElapsedSinceActivation: 2,
                activationTime: activation)
        }
    }
}
