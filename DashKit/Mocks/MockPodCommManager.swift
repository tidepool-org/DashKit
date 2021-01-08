//
//  MockPodCommManager.swift
//  DashKit
//
//  Created by Pete Schwamb on 6/27/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import PodSDK
import LoopKit

public protocol MockPodCommManagerObserver: class {
    func mockPodCommManagerDidUpdate()
}

public class MockPodCommManager: PodCommManagerProtocol {
    
    // Nil if no pod paired
    public var podStatus: MockPodStatus? {
        didSet {
            notifyObservers()
        }
    }
        
    public var silencedAlerts: [PodAlerts] = []
    
    public var podCommState: PodCommState = .noPod {
        didSet {
            self.dashPumpManager?.podCommManager(self, podCommStateDidChange: podCommState)
            notifyObservers()
        }
    }
    
    private var observers = WeakSynchronizedSet<MockPodCommManagerObserver>()
    
    public func addObserver(_ observer: MockPodCommManagerObserver, queue: DispatchQueue) {
        observers.insert(observer, queue: queue)
    }

    public func removeObserver(_ observer: MockPodCommManagerObserver) {
        observers.removeElement(observer)
    }
    
    public func notifyObservers() {
        observers.forEach { (observer) in
            observer.mockPodCommManagerDidUpdate()
        }
    }

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

    public func startPodActivation(lowReservoirAlert: LowReservoirAlert?, podExpirationAlert: PodExpirationAlert?, eventListener: @escaping (ActivationStatus<ActivationStep1Event>) -> ()) {

        pairAttemptCount += 1
        
        if pairAttemptCount == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                eventListener(.error(self.initialPairError))
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                eventListener(.event(.connecting))
                self.dashPumpManager?.podCommManager(self, connectionStateDidChange: .tryConnecting)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                self.dashPumpManager?.podCommManager(self, connectionStateDidChange: .connected)
                self.podCommState = .activating
                eventListener(.event(.retrievingPodVersion))
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                eventListener(.event(.settingPodUid))
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 11) {
                eventListener(.event(.programmingLowReservoirAlert))
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 11.5) {
                // Start out with 100U
                self.podStatus = MockPodStatus(activationDate: Date(), podState: .uidSet, programStatus: ProgramStatus(rawValue: 0), activeAlerts: PodAlerts(rawValue: 128), isOcclusionAlertActive: false, bolusUnitsRemaining: 0, initialInsulinAmount: 100)
                eventListener(.event(.podStatus(self.podStatus!)))
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
                eventListener(.event(.programmingLumpOfCoal))
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 12.5) {
                self.podStatus!.activeAlerts = PodAlerts(rawValue: 0)
                eventListener(.event(.podStatus(self.podStatus!)))
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 12.8) {
                eventListener(.event(.primingPod))
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                self.podStatus!.podState = .engagingClutchDrive
                eventListener(.event(.podStatus(self.podStatus!)))
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                eventListener(.event(.checkingPodStatus))
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 30.5) {
                self.podStatus!.podState = .clutchDriveEnaged
                self.podStatus!.insulinDelivered = 1.40
                eventListener(.event(.podStatus(self.podStatus!)))
                eventListener(.event(.programmingPodExpireAlert))
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 31) {
                eventListener(.event(.podStatus(self.podStatus!)))
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 32) {
                eventListener(.event(.step1Completed))
            }
        }
    }
    
    private var insertCannulaAttemptCount = 0
    var initialCannulaInsertionError: PodCommError = .bleCommunicationError
    
    public func finishPodActivation(basalProgram: ProgramType, autoOffAlert: AutoOffAlert?, eventListener: @escaping (ActivationStatus<ActivationStep2Event>) -> ()) {
        insertCannulaAttemptCount += 1
        
        guard case .basalProgram(let basalProgram, let secondsSinceMidnight) = basalProgram else {
            eventListener(.error(.invalidProgram))
            return
        }
        
        if insertCannulaAttemptCount == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                eventListener(.error(self.initialCannulaInsertionError))
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                eventListener(.event(.programmingActiveBasal))
                self.podStatus?.basalProgram = basalProgram
                self.podStatus?.basalProgramStartOffset = secondsSinceMidnight.map {Double($0)} ?? -Calendar.current.startOfDay(for: Date()).timeIntervalSinceNow
                self.podStatus?.basalProgramStartDate = Date()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.podStatus!.podState = .basalProgramRunning
                self.podStatus!.activeAlerts = PodAlerts(rawValue: 128)
                eventListener(.event(.podStatus(self.podStatus!)))
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                eventListener(.event(.cancelLumpOfCoalProgrammingAutoOff))
                self.podStatus!.activeAlerts = PodAlerts(rawValue: 0)
                eventListener(.event(.podStatus(self.podStatus!)))
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                eventListener(.event(.insertingCannula))
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                self.podStatus!.podState = .priming
                self.podStatus!.bolusUnitsRemaining = 50
                eventListener(.event(.podStatus(self.podStatus!)))
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 14) {
                eventListener(.event(.checkingPodStatus))
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                self.podStatus!.podState = .runningAboveMinVolume
                self.podStatus!.bolusUnitsRemaining = 0
                self.podStatus!.insulinDelivered = 1.90
                eventListener(.event(.podStatus(self.podStatus!)))
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 16) {
                self.podCommState = .active
                eventListener(.event(.step2Completed))
            }
        }
    }
    
    public func issueAlerts(_ alerts: PodAlerts) {
        if var podStatus = podStatus {
            podStatus.activeAlerts.insert(alerts)
            self.podStatus = podStatus
            self.dashPumpManager?.podCommManagerHasAlerts(podStatus.activeAlerts)
        }
    }
    
    public func clearAlerts(_ alerts: PodAlerts) {
        if var podStatus = podStatus {
            podStatus.activeAlerts.remove(alerts)
            self.podStatus = podStatus
            self.dashPumpManager?.podCommManagerHasAlerts(podStatus.activeAlerts)
        }
    }

    public func discardPod(completion: @escaping (PodCommResult<Bool>) -> ()) {
        deliveryProgramError = nil
        unacknowledgedCommandRetryResult = nil
        completion(.success(true))
    }

    public func deactivatePod(completion: @escaping (PodCommResult<PartialPodStatus>) -> ()) {
        guard let podStatus = podStatus else {
            completion(.failure(.podIsNotActive))
            return
        }
        
        setDeactivatedState()
        deliveryProgramError = nil
        unacknowledgedCommandRetryResult = nil
        completion(.success(podStatus))
    }
    
    private func setDeactivatedState() {
        podStatus = nil
        podCommState = .noPod
    }
    
    public func getPodStatus(userInitiated: Bool, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        self.podStatus?.updateDelivery()
        
        guard let podStatus = podStatus else {
            completion(.failure(.podIsNotActive))
            return
        }

        completion(.success(podStatus))
    }

    public func getAlertsDetails(completion: @escaping (PodCommResult<PodAlerts>) -> ()) {
        completion(.success(PodAlerts(rawValue: 0)))
    }

    public func playTestBeeps(completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        guard let podStatus = podStatus else {
            completion(.failure(.podIsNotActive))
            return
        }
        
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
        self.podStatus?.updateDelivery()

        guard var podStatus = podStatus else {
            completion(.failure(.podIsNotActive))
            return
        }
        
        if let error = deliveryProgramError {
            if simulateDisconnectionOnUnacknowledgedCommand, case .unacknowledgedCommandPendingRetry = error {
                disconnectFor(.minutes(1))
            }
            completion(.failure(error))
        } else {
            switch programType {
            case .basalProgram(let program, let offset):
                let now = Date()
                self.podStatus!.basalProgram = program
                self.podStatus!.basalProgramStartOffset = offset.map {Double($0)} ?? -Calendar.current.startOfDay(for: now).timeIntervalSinceNow
                self.podStatus!.basalProgramStartDate = now
                podStatus.programStatus.insert(.basalRunning)
            case .bolus(let bolus):
                self.podStatus!.bolus = UnfinalizedDose(
                    bolusAmount: Double(bolus.immediateVolume) / Pod.podSDKInsulinMultiplier,
                    startTime: Date(),
                    scheduledCertainty: .certain)
                podStatus.programStatus.insert(.bolusRunning)
            case .tempBasal(let tempBasal):
                if case .flatRate(let rate) = tempBasal.value {
                    self.podStatus!.tempBasal = UnfinalizedDose(tempBasalRate: Double(rate) / Pod.podSDKInsulinMultiplier, startTime: Date(), duration: tempBasal.duration, scheduledCertainty: .certain)
                    podStatus.programStatus.insert(.tempBasalRunning)
                }
            }
            self.podStatus = podStatus
            completion(.success(podStatus))
        }
    }

    public func stopProgram(programType: StopProgramType, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        guard var podStatus = podStatus else {
            completion(.failure(.podIsNotActive))
            return
        }
        
        if let error = deliveryProgramError {
            if simulateDisconnectionOnUnacknowledgedCommand, case .unacknowledgedCommandPendingRetry = error {
                disconnectFor(.minutes(1))
            }
            completion(.failure(error))
        } else {
            switch programType {
            case .bolus:
                self.podStatus?.cancelBolus()
                podStatus.programStatus.remove(.bolusRunning)
            case .tempBasal:
                self.podStatus?.cancelTempBasal()
                podStatus.programStatus.remove(.tempBasalRunning)
            case .stopAll:
                self.podStatus?.cancelBolus()
                self.podStatus?.cancelTempBasal()
                podStatus.programStatus = []
            }
            self.podStatus = podStatus
            completion(.success(podStatus))
        }
    }

    public func updateAlertSetting(alertSetting: PodAlertSetting, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        guard let podStatus = podStatus else {
            completion(.failure(.podIsNotActive))
            return
        }

        completion(.success(podStatus))
    }

    public func silenceAlerts(alert: PodAlerts, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        guard let podStatus = podStatus else {
            completion(.failure(.podIsNotActive))
            return
        }
        self.podStatus!.activeAlerts = podStatus.activeAlerts.subtracting(alert)
        silencedAlerts.append(alert)
        completion(.success(self.podStatus!))
    }

    public func retryUnacknowledgedCommand(completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        guard let podStatus = podStatus else {
            completion(.failure(.podIsNotActive))
            return
        }
        
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
        guard let podStatus = podStatus else {
            completion(.failure(.podIsNotActive))
            return
        }
        
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
        self.podStatus = podStatus
        if podStatus != nil {
            self.podCommState = .active
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

