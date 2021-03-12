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
    
    public let dateGenerator: () -> Date
    
    public var simulatedCommsDelay = TimeInterval(2)
    
    private let lockedPodStatus: Locked<MockPodStatus?>
    
    public var podStatus: MockPodStatus? {
        get {
            return lockedPodStatus.value
        }
        set {
            var oldStatus: MockPodStatus?
            lockedPodStatus.mutate { (status) in
                oldStatus = status
                status = newValue
            }
            notifyObservers()
            
            if let oldStatus = oldStatus, let newStatus = newValue {
                if oldStatus.lowReservoirAlertConditionActive != newStatus.lowReservoirAlertConditionActive {
                    if newStatus.lowReservoirAlertConditionActive {
                        issueAlerts(.lowReservoir)
                    } else {
                        clearAlerts(.lowReservoir)
                    }
                }
            }
        }
    }
        
    public var silencedAlerts: [PodAlerts] = []

    private let lockedPodCommState: Locked<PodCommState>

    public var podCommState: PodCommState {
        get {
            return podStatus?.podCommState ?? .noPod
        }
        set {
            podStatus?.podCommState = newValue
            self.dashPumpManager?.podCommManager(self, podCommStateDidChange: newValue)
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

    public var nextCommsError: PodCommError?

    public var delegate: PodCommManagerDelegate?

    // We can't call PodCommManagerDelegate methods on DashPumpManager because we do not have a real PodCommManager.
    // We can use a direct reference to call the mirrored delegate methods, that expect PodCommManagerProtocol.
    public weak var dashPumpManager: DashPumpManager?
    
    public func setLogger(logger: LoggingProtocol) { }

    public func setup(withLaunchingOptions launchOptions: [AnyHashable : Any]?) { }

    public var unacknowledgedCommandRetryResult: PendingRetryResult?
    
    public var simulateDisconnectionOnUnacknowledgedCommand: Bool = false
    
    public var bleConnected: Bool = true

    public func startPodActivation(lowReservoirAlert: LowReservoirAlert?, podExpirationAlert: PodExpirationAlert?, eventListener: @escaping (ActivationStatus<ActivationStep1Event>) -> ()) {
        
        var incompatiblePod = false
        
        if let commsError = nextCommsError {
            nextCommsError = nil
            if case .internalError(let code) = commsError, code == .incompatibleProductId {
                incompatiblePod = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    eventListener(.error(commsError))
                }
                return
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            eventListener(.event(.connecting))
            self.dashPumpManager?.podCommManager(self, connectionStateDidChange: .tryConnecting)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
            self.dashPumpManager?.podCommManager(self, connectionStateDidChange: .connected)
            // Start out with 100U
            self.podStatus = MockPodStatus(activationDate: self.dateGenerator(), podState: .uninitialized, programStatus: ProgramStatus(rawValue: 0), activeAlerts: PodAlerts(rawValue: 128), bolusUnitsRemaining: 0, initialInsulinAmount: 100)
            self.podCommState = .activating
            eventListener(.event(.retrievingPodVersion))
            if incompatiblePod {
                eventListener(.error(.internalError(.incompatibleProductId)))
            }
        }
        
        if incompatiblePod {
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            eventListener(.event(.settingPodUid))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 11) {
            eventListener(.event(.programmingLowReservoirAlert))
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 11.5) {
            self.podStatus?.podState = .uidSet
            self.podStatus?.lowReservoirAlert = lowReservoirAlert
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
            self.podStatus!.podState = .clutchDriveEngaged
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
    
    public func finishPodActivation(basalProgram: ProgramType, autoOffAlert: AutoOffAlert?, eventListener: @escaping (ActivationStatus<ActivationStep2Event>) -> ()) {

        guard case .basalProgram(let basalProgram, let secondsSinceMidnight) = basalProgram else {
            eventListener(.error(.invalidProgram))
            return
        }
        
        if let error = nextCommsError {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                eventListener(.error(error))
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                eventListener(.event(.programmingActiveBasal))
                self.podStatus?.basalProgram = basalProgram
                self.podStatus?.basalProgramStartOffset = secondsSinceMidnight.map {Double($0)} ?? -Calendar.current.startOfDay(for: self.dateGenerator()).timeIntervalSinceNow
                self.podStatus?.basalProgramStartDate = self.dateGenerator()
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
    
    public func triggerAlarm(_ alarmCode: AlarmCode, alarmDate: Date = Date()) {
        guard var podStatus = podStatus else {
            return
        }
        podStatus.enterAlarmState(alarmCode: alarmCode, alarmDescription: String(describing: alarmCode), didErrorOccuredFetchingBolusInfo: false, alarmDate: alarmDate, referenceCode: "0000-mock-pod-0000")
        self.podStatus = podStatus
        let alarmDetail = podStatus.alarmDetail!
        self.podCommState = .alarm(alarmDetail)
        self.dashPumpManager?.podCommManager(self, didAlarm: alarmDetail)
    }
    
    public func triggerSystemError() {
        let systemError = Self.systemError
        self.podCommState = .systemError(systemError)
        dashPumpManager?.podCommManagerHasSystemError(error: systemError)
    }

    public func discardPod(completion: @escaping (PodCommResult<Bool>) -> ()) {
        nextCommsError = nil
        unacknowledgedCommandRetryResult = nil
        completion(.success(true))
    }

    public func deactivatePod(completion: @escaping (PodCommResult<PartialPodStatus>) -> ()) {
        guard let podStatus = podStatus else {
            completion(.failure(.podIsNotActive))
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.setDeactivatedState()
            self.nextCommsError = nil
            self.unacknowledgedCommandRetryResult = nil
            completion(.success(podStatus))
        }
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
        
        // SDK returns .invalidProgram if bolus attempt is made during suspension.
        if case .bolus = programType, podStatus.programStatus.isSuspended {
            completion(.failure(.invalidProgram))
            return
        }
        
        if let error = nextCommsError {
            errorTriggered()
            completion(.failure(error))
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + simulatedCommsDelay) {
                switch programType {
                case .basalProgram(let program, let offset):
                    let now = self.dateGenerator()
                    podStatus.basalProgram = program
                    podStatus.basalProgramStartOffset = offset.map {Double($0)} ?? -Calendar.current.startOfDay(for: now).timeIntervalSinceNow
                    podStatus.basalProgramStartDate = now
                    podStatus.programStatus.insert(.basalRunning)
                case .bolus(let bolus):
                    podStatus.bolus = UnfinalizedDose(
                        bolusAmount: Double(bolus.immediateVolume) / Pod.podSDKInsulinMultiplier,
                        startTime: self.dateGenerator(),
                        scheduledCertainty: .certain)
                    podStatus.programStatus.insert(.bolusRunning)
                case .tempBasal(let tempBasal):
                    if case .flatRate(let rate) = tempBasal.value {
                        podStatus.tempBasal = UnfinalizedDose(tempBasalRate: Double(rate) / Pod.podSDKInsulinMultiplier, startTime: self.dateGenerator(), duration: tempBasal.duration, scheduledCertainty: .certain)
                        podStatus.programStatus.insert(.tempBasalRunning)
                    }
                }
                self.podStatus = podStatus
                completion(.success(podStatus))
            }
        }
    }

    public func stopProgram(programType: StopProgramType, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        guard var podStatus = podStatus else {
            completion(.failure(.podIsNotActive))
            return
        }
        
        if let error = nextCommsError {
            errorTriggered()
            completion(.failure(error))
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + simulatedCommsDelay) {
                switch programType {
                case .bolus:
                    podStatus.cancelBolus(at: self.dateGenerator())
                    podStatus.programStatus.remove(.bolusRunning)
                case .tempBasal:
                    podStatus.cancelTempBasal(at: self.dateGenerator())
                    podStatus.programStatus.remove(.tempBasalRunning)
                case .stopAll:
                    podStatus.cancelBolus(at: self.dateGenerator())
                    podStatus.cancelTempBasal(at: self.dateGenerator())
                    podStatus.programStatus = []
                }
                self.podStatus = podStatus
                completion(.success(podStatus))
            }
        }
    }

    public func updateAlertSetting(alertSetting: PodAlertSetting, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        guard let podStatus = podStatus else {
            completion(.failure(.podIsNotActive))
            return
        }
        if let error = nextCommsError {
            errorTriggered()
            completion(.failure(error))
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + simulatedCommsDelay) {
                completion(.success(podStatus))
            }
        }
    }
    
    private func errorTriggered() {
        if let error = nextCommsError {
            if simulateDisconnectionOnUnacknowledgedCommand, case .unacknowledgedCommandPendingRetry = error {
                disconnectFor(.minutes(1))
            }
            nextCommsError = nil
        }
    }

    public func silenceAlerts(alert: PodAlerts, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        guard var podStatus = podStatus else {
            completion(.failure(.podIsNotActive))
            return
        }
        podStatus.activeAlerts = podStatus.activeAlerts.subtracting(alert)
        silencedAlerts.append(alert)
        self.podStatus = podStatus
        completion(.success(podStatus))
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
        return "1234"
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

    public init(podStatus: MockPodStatus? = nil, dateGenerator: (() -> Date)? = nil) {
        self.lockedPodStatus = Locked(podStatus)
        if let podStatus = podStatus {
            if podStatus.podState == .alarm, let alarmDetail = podStatus.alarmDetail {
                self.lockedPodCommState = Locked(.alarm(alarmDetail))
            } else {
                self.lockedPodCommState = Locked(.active)
            }
        } else {
            self.lockedPodCommState = Locked(.noPod)
        }
        self.dateGenerator = dateGenerator ?? { return Date() }
    }
    
    public static var systemError: SystemError {
        let json = "{\"error\":\"dataCorruption\",\"referenceCode\":\"01-mock-pod-003\"}"
        return try! JSONDecoder().decode(SystemError.self, from: json.data(using: .utf8)!)
    }
}

extension PendingRetryResult {
    public static var wasProgrammed: PendingRetryResult {
        return PendingRetryResult(status: MockPodStatus.normal, hasPendingCommandProgrammed: true)
    }

    public static var wasNotProgrammed: PendingRetryResult {
        return PendingRetryResult(status: MockPodStatus.normal, hasPendingCommandProgrammed: false)
    }
}

