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
    
    // Create a shared MockPodCommManager for running on the simulator
    public static let shared: MockPodCommManager = {
        var mock = MockPodCommManager()
        mock.simulateDisconnectionOnUnacknowledgedCommand = true
        return mock
    }()

    // Record for test inspection
    var lastBolusVolume: Int?
    var lastBasalProgram: BasalProgram?
    var lastTempBasal: TempBasal?

    public var podStatus: MockPodStatus
        
    public var silencedAlerts: [PodAlerts] = []
    
    public var podCommState: PodCommState = .noPod

    public var deliveryProgramError: PodCommError?

    public var delegate: PodCommManagerDelegate?
    
    // We can't call PodCommManagerDelegate methods on DashPumpManager because we do not have a real PodCommManager.
    // We can use a direct reference to call the mirrored delegate methods, that expect PodCommManagerProtocol.
    public weak var dashPumpManager: DashPumpManager?
    
    public func setLogger(logger: LoggingProtocol) { }

    public func setup(withLaunchingOptions launchOptions: [AnyHashable : Any]?) { }

    var pairAttemptCount = 0
    var initialPairError: PodCommError = .podNotAvailable
    
    public var unacknowledgedCommandRetryResult: PendingRetryResult?
    
    public var simulateDisconnectionOnUnacknowledgedCommand: Bool = false
    
    public var bleConnected: Bool = true

    public func update(for state: DashPumpManagerState) {
        guard state.suspendState != nil else {
            setDeactivatedState()
            return
        }
        
        podStatus.reservoirUnitsRemaining = state.reservoirLevel?.rawValue ?? 0
    }
    
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
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Pod.estimatedCannulaInsertionDuration) {
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
                eventListener(.event(.podStatus(self.podStatus)))
            }
        }
    }
    
    public func issueAlerts(_ alerts: PodAlerts) {
        self.podStatus.activeAlerts.insert(alerts)
        self.dashPumpManager?.podCommManagerHasAlerts(self.podStatus.activeAlerts)
    }
    
    public func clearAlerts(_ alerts: PodAlerts) {
        self.podStatus.activeAlerts.remove(alerts)
        self.dashPumpManager?.podCommManagerHasAlerts(self.podStatus.activeAlerts)
    }

    public func discardPod(completion: @escaping (PodCommResult<Bool>) -> ()) {
        deliveryProgramError = nil
        unacknowledgedCommandRetryResult = nil
        completion(.success(true))
    }

    public func deactivatePod(completion: @escaping (PodCommResult<PartialPodStatus>) -> ()) {
        setDeactivatedState()
        deliveryProgramError = nil
        unacknowledgedCommandRetryResult = nil
        completion(.success(podStatus))
    }
    
    private func setDeactivatedState() {
        podStatus = MockPodStatus(expirationDate: podStatus.expirationDate,
                                  podState: .deactivated,
                                  programStatus: [],
                                  activeAlerts: [],
                                  isOcclusionAlertActive: false,
                                  bolusUnitsRemaining: 0,
                                  totalUnitsDelivered: 0,
                                  reservoirUnitsRemaining: 0,
                                  timeElapsedSinceActivation: Date().timeIntervalSince(podStatus.activationTime),
                                  activationTime: podStatus.activationTime)
        podCommState = .noPod
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
    
    public func disconnectFor(_ interval: TimeInterval) {
        bleConnected = false
        self.dashPumpManager?.podCommManager(self, connectionStateDidChange: .disconnected)
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            self.bleConnected = true
            self.dashPumpManager?.podCommManager(self, connectionStateDidChange: .connected)
        }
    }

    public func sendProgram(programType: ProgramType, beepOption: BeepOption?, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        if let error = deliveryProgramError {
            if simulateDisconnectionOnUnacknowledgedCommand, case .unacknowledgedCommandPendingRetry = error {
                disconnectFor(.minutes(1))
            }
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
        if let error = deliveryProgramError {
            if simulateDisconnectionOnUnacknowledgedCommand, case .unacknowledgedCommandPendingRetry = error {
                disconnectFor(.minutes(1))
            }
            completion(.failure(error))
        } else {
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
    }

    public func updateAlertSetting(alertSetting: PodAlertSetting, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(podStatus))
    }

    public func silenceAlerts(alert: PodAlerts, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        silencedAlerts.append(alert)
        completion(.success(podStatus))
    }

    public func retryUnacknowledgedCommand(completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(podStatus))
    }

    public func queryAndClearUnacknowledgedCommand(completion: @escaping (PodCommResult<PendingRetryResult>) -> ()) {
        guard bleConnected else {
            completion(.failure(.bleCommunicationError))
            return
        }
        
        if let retryResult = unacknowledgedCommandRetryResult {
            completion(.success(retryResult))
        } else {
            completion(.success(.wasNotProgrammed))
        }
    }
    
    public func updateBeepOptions(bolusReminder: BeepOption, tempBasalReminder: BeepOption, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        completion(.success(podStatus))
    }
    
    public func configPeriodicStatusCheck(interval: TimeInterval, completion: @escaping (PodCommResult<Bool>) -> ()) {
        completion(.success(true))
    }
    
    public func disablePeriodicStatusCheck(completion: @escaping (PodCommResult<Bool>) -> ()) {
        completion(.success(true))
    }

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

extension PendingRetryResult {
    public static var wasProgrammed: PendingRetryResult {
        let decoder = JSONDecoder()
        let json = "{\"hasPendingCommandProgrammed\":true,\"podStatus\":{\"bolusPulsesRemaining\":1,\"podState\":13,\"lastSequenceNumber\":1,\"reservoirPulsesRemaining\":1020,\"activeAlerts\":0,\"pulsesDelivered\":20,\"programStatus\":\"Basal\",\"timeSinceActivationInMins\":1,\"receivedAt\":\(Date().timeIntervalSinceReferenceDate),\"dataCorrupted\":false,\"isOcclusionAlertActive\":false}}"
        return try! decoder.decode(PendingRetryResult.self, from: json.data(using: .utf8)!)
    }

    public static var wasNotProgrammed: PendingRetryResult {
        let decoder = JSONDecoder()
        let json = "{\"hasPendingCommandProgrammed\":false,\"podStatus\":{\"bolusPulsesRemaining\":1,\"podState\":13,\"lastSequenceNumber\":1,\"reservoirPulsesRemaining\":1020,\"activeAlerts\":0,\"pulsesDelivered\":20,\"programStatus\":\"Basal\",\"timeSinceActivationInMins\":1,\"receivedAt\":\(Date().timeIntervalSinceReferenceDate),\"dataCorrupted\":false,\"isOcclusionAlertActive\":false}}"
        return try! decoder.decode(PendingRetryResult.self, from: json.data(using: .utf8)!)
    }
}

