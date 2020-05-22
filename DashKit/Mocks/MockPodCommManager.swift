//
//  MockPodCommManager.swift
//  DashKit
//
//  Created by Pete Schwamb on 6/27/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import PodSDK


public class MockPodCommManager: PodCommManagerProtocol {

    public func updateBeepOptions(bolusReminder: BeepOption, tempBasalReminder: BeepOption, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(podStatus))
    }
    
    func verifyUnacknowledgedCommand(withRetry: Bool, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(podStatus))
    }
    
    public func configPeriodicStatusCheck(interval: TimeInterval, completion: @escaping (PodCommResult<Bool>) -> ()) {
        completion(.success(true))
    }
    
    public func disablePeriodicStatusCheck(completion: @escaping (PodCommResult<Bool>) -> ()) {
        completion(.success(true))
    }
    
    // Record for test inspection
    var lastBolusVolume: Int?
    var lastBasalProgram: BasalProgram?
    var lastTempBasal: TempBasal?

    var podStatus: MockPodStatus
    
    public var podCommState: PodCommState = .noPod

    var sendProgramFailureError: PodCommError?

    public var delegate: PodCommManagerDelegate?

    public func setLogger(logger: LoggingProtocol) { }

    public func setup(withLaunchingOptions launchOptions: [AnyHashable : Any]?) { }

    var pairAttemptCount = 0
    var initialPairError: PodCommError = .podNotAvailable

    public func startPodActivation(lowReservoirAlert: LowReservoirAlert?, podExpirationAlert: PodExpirationAlert?, eventListener: @escaping (ActivationStatus<ActivationStep1Event>) -> ()) {

        pairAttemptCount += 1
        
        if pairAttemptCount == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                eventListener(.error(self.initialPairError))
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                eventListener(.event(.connecting))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.podCommState = .activating
                eventListener(.event(.primingPod))
            }
            // Priming is normally 35s, but we'll send the completion faster in the mock
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                self.podCommState = .active
                eventListener(.event(.step1Completed))
            }
        }
    }
    
    private var insertCannulaAttemptCount = 0
    var initialCannulaInsertionError: PodCommError = .bleCommunicationError
    
    public func finishPodActivation(basalProgram: ProgramType, autoOffAlert: AutoOffAlert?, eventListener: @escaping (ActivationStatus<ActivationStep2Event>) -> ()) {
        insertCannulaAttemptCount += 1
        
        if insertCannulaAttemptCount == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                eventListener(.error(self.initialCannulaInsertionError))
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                eventListener(.event(.insertingCannula))
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Pod.estimatedCannulaInsertionDuration) {
                eventListener(.event(.step2Completed))
            }
        }
    }

    public func discardPod(completion: @escaping (PodCommResult<Bool>) -> ()) {
        completion(.success(true))
    }

    public func deactivatePod(completion: @escaping (PodCommResult<PartialPodStatus>) -> ()) {
        self.podStatus = MockPodStatus(expirationDate: podStatus.expirationDate, podState: .deactivated, programStatus: [], activeAlerts: [], isOcclusionAlertActive: false, bolusUnitsRemaining: 0, totalUnitsDelivered: 0, reservoirUnitsRemaining: 0, timeElapsedSinceActivation: Date().timeIntervalSince(podStatus.activationTime), activationTime: podStatus.activationTime)
        self.podCommState = .noPod
        completion(.success(podStatus))
    }
    
    public func getPodStatus(userInitiated: Bool, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(podStatus))
    }

    public func getAlertsDetails(completion: @escaping (PodCommResult<PodAlerts>) -> ()) {
        completion(.success(PodAlerts(rawValue: 0)))
    }

    public func playTestBeeps(completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(podStatus))
    }

    public func sendProgram(programType: ProgramType, beepOption: BeepOption?, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        if let error = sendProgramFailureError {
            completion(.failure(error))
        } else {
            switch programType {
            case .basalProgram(let program, _):
                lastBasalProgram = program
                podStatus.programStatus.insert(.basalRunning)
            case .bolus(let bolus):
                lastBolusVolume = bolus.immediateVolume
                podStatus.programStatus.insert(.bolusRunning)
            case .tempBasal(let tempBasal):
                lastTempBasal = tempBasal
                podStatus.programStatus.insert(.tempBasalRunning)
            }
            completion(.success(podStatus))
        }
    }

    public func stopProgram(programType: StopProgramType, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        switch programType {
        case .bolus:
            podStatus.programStatus.remove(.bolusRunning)
        case .tempBasal:
            podStatus.programStatus.remove(.tempBasalRunning)
        case .stopAll:
            podStatus.programStatus = []
        }
        completion(.success(podStatus))
    }

    public func updateAlertSetting(alertSetting: PodAlertSetting, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(podStatus))
    }

    public func silenceAlerts(alert: PodAlerts, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(podStatus))
    }

    public func retryUnacknowledgedCommand(completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(podStatus))
    }

    public func queryAndClearUnacknowledgedCommand(completion: @escaping (PodCommResult<PendingRetryResult>) -> ()) { }

    public func retrievePDMId() -> String? {
        return "Mock PDM Identifier"
    }
    
    public var podVersionAbstracted: PodVersionProtocol? {
        return MockPodVersion(lotNumber: 123, sequenceNumber: 1234, majorVersion: 1, minorVersion: 1, interimVersion: 1, bleMajorVersion: 1, bleMinorVersion: 1, bleInterimVersion: 1)
    }
    
    public func getEstimatedBolusDeliveryTime() -> TimeInterval? {
        return nil
    }

    public func getEstimatedBolusRemaining() -> Int {
        return 0
    }

    public init(podStatus: MockPodStatus? = nil) {
        if let podStatus = podStatus {
            self.podStatus = podStatus
        } else {
            let activation = Date() - TimeInterval(hours: 35)
            self.podStatus = MockPodStatus(
                expirationDate: activation + Pod.lifetime,
                podState: .alarm,
                programStatus: .basalRunning,
                activeAlerts: PodAlerts([]),
                isOcclusionAlertActive: false,
                bolusUnitsRemaining: 0,
                totalUnitsDelivered: 38,
                reservoirUnitsRemaining: 1023,
                timeElapsedSinceActivation: 2,
                activationTime: activation)
            self.podCommState = .active // .alarm(MockPodAlarm.occlusion)
        }
    }
}
