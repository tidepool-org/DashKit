//
//  DashPumpManager.swift
//  DashKit
//
//  Created by Pete Schwamb on 4/18/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit
import os.log
import PodSDK


public protocol PodStatusObserver: class {
    func didUpdatePodStatus()
}

public class DashPumpManager: PumpManager {
    
    public static var managerIdentifier = "OmnipodDash"
    
    static let podAlarmNotificationIdentifier = "DASH:\(LoopNotificationCategory.pumpFault.rawValue)"

    public var podCommManager: PodCommManagerProtocol

    public let log = OSLog(category: "DashPumpManager")
    
    public static let localizedTitle = LocalizedString("Omnipod DASH", comment: "Generic title of the omnipod DASH pump manager")
    
    public var lastReconciliation: Date? {
        return dateGenerator()
    }

    public func roundToSupportedBasalRate(unitsPerHour: Double) -> Double {
         return supportedBasalRates.filter({$0 <= unitsPerHour}).max() ?? 0
    }

    public func roundToSupportedBolusVolume(units: Double) -> Double {
        return supportedBolusVolumes.filter({$0 <= units}).max() ?? 0
    }

    public var supportedBolusVolumes: [Double] {
        // 0.05 units for rates between 0.05-30U
        return (1...600).map { Double($0) / Double(Pod.pulsesPerUnit) }
    }

    public var supportedBasalRates: [Double] {
        // 0.05 units for rates between 0.05-30U/hr
        return (1...600).map { Double($0) / Double(Pod.pulsesPerUnit) }
    }

    public var maximumBasalScheduleEntryCount: Int {
        return Pod.maximumBasalScheduleEntryCount
    }

    public var minimumBasalScheduleEntryDuration: TimeInterval {
        return Pod.minimumBasalScheduleEntryDuration
    }

    private let pumpDelegate = WeakSynchronizedDelegate<PumpManagerDelegate>()

    public var pumpManagerDelegate: PumpManagerDelegate? {
        get {
            return pumpDelegate.delegate
        }
        set {
            pumpDelegate.delegate = newValue
        }
    }

    public var delegateQueue: DispatchQueue! {
        get {
            return pumpDelegate.queue
        }
        set {
            pumpDelegate.queue = newValue
        }
    }

    public let pumpRecordsBasalProfileStartEvents = false

    public var pumpReservoirCapacity: Double {
        return Pod.reservoirCapacity
    }

    public var hasActivePod: Bool {
        return state.podActivatedAt != nil
    }
    
    // Primarily used for testing
    public let dateGenerator: () -> Date

    public var state: DashPumpManagerState {
        return lockedState.value
    }
    
    private func pumpStatusHighlight(for state: DashPumpManagerState) -> PumpManagerStatus.PumpStatusHighlight? {
        if state.pendingCommand != nil {
            return PumpManagerStatus.PumpStatusHighlight(localizedMessage: NSLocalizedString("Comms Issue", comment: "Status highlight that delivery is uncertain."),
                                                         imageName: "exclamationmark.circle.fill",
                                                         state: .critical)
        }

        switch podCommManager.podCommState {
        case .activating:
            return PumpManagerStatus.PumpStatusHighlight(
                localizedMessage: NSLocalizedString("Pod Activating", comment: "Status highlight that when pod is activating."),
                imageName: "exclamationmark.circle.fill",
                state: .warning)
        case .deactivating:
            return PumpManagerStatus.PumpStatusHighlight(
                localizedMessage: NSLocalizedString("Pod Deactivating", comment: "Status highlight that when pod is deactivating."),
                imageName: "exclamationmark.circle.fill",
                state: .warning)
        case .noPod:
            return PumpManagerStatus.PumpStatusHighlight(
                localizedMessage: NSLocalizedString("No Pod", comment: "Status highlight that when no pod is paired."),
                imageName: "exclamationmark.circle.fill",
                state: .warning)
        case .alarm(let detail):
            if let detail = detail, detail.occlusionType != .none {
                return PumpManagerStatus.PumpStatusHighlight(
                    localizedMessage: NSLocalizedString("Occlusion", comment: "Status highlight that when pod is alarming with occlusion."),
                    imageName: "exclamationmark.circle.fill",
                    state: .critical)
            } else {
                return PumpManagerStatus.PumpStatusHighlight(
                    localizedMessage: NSLocalizedString("Pod Alarm", comment: "Status highlight that when pod has non-occlusion alarm."),
                    imageName: "exclamationmark.circle.fill",
                    state: .critical)
            }
        case .systemError:
            return PumpManagerStatus.PumpStatusHighlight(
                localizedMessage: NSLocalizedString("System Error", comment: "Status highlight that when pod has a system error."),
                imageName: "exclamationmark.circle.fill",
                state: .critical)
        case .active:
            if let reservoirPercent = state.reservoirLevel?.asPercentage(), reservoirPercent == 0 {
                return PumpManagerStatus.PumpStatusHighlight(
                    localizedMessage: NSLocalizedString("No Insulin", comment: "Status highlight that a pump is out of insulin."),
                    imageName: "exclamationmark.circle.fill",
                    state: .critical)
            } else if case .suspended = state.suspendState {
                return PumpManagerStatus.PumpStatusHighlight(
                    localizedMessage: NSLocalizedString("Insulin Suspended", comment: "Status highlight that insulin delivery was suspended."),
                    imageName: "pause.circle.fill",
                    state: .warning)
            }
            return nil
        }
    }

    
    private func status(for state: DashPumpManagerState) -> PumpManagerStatus {
        return PumpManagerStatus(
            timeZone: state.timeZone,
            device: device,
            pumpBatteryChargeRemaining: nil,
            basalDeliveryState: basalDeliveryState(for: state),
            bolusState: bolusState(for: state),
            pumpStatusHighlight: pumpStatusHighlight(for: state),
            deliveryIsUncertain: state.pendingCommand != nil
        )
    }
    
    @discardableResult private func mutateState(_ changes: (_ state: inout DashPumpManagerState) -> Void) -> DashPumpManagerState {
        return setStateWithResult({ (state) -> DashPumpManagerState in
            changes(&state)
            return state
        })
    }
    
    private func setStateWithResult<ReturnType>(_ changes: (_ state: inout DashPumpManagerState) -> ReturnType) -> ReturnType {
        var oldValue: DashPumpManagerState!
        var returnValue: ReturnType!
        let newValue = lockedState.mutate { (state) in
            oldValue = state
            returnValue = changes(&state)
        }
        
        podStatusObservers.forEach { (observer) in
            observer.didUpdatePodStatus()
        }
        
        guard oldValue != newValue else {
            return returnValue
        }
        
        // PumpManagerStatus may have changed
        let oldStatus = status(for: oldValue)
        let newStatus = status(for: state)
        
        if oldStatus != newStatus {
            notifyStatusObservers(oldStatus: oldStatus)
        }
        
        pumpDelegate.notify { (delegate) in
            if oldValue != nil,
                newValue.reservoirLevel != oldValue.reservoirLevel,
                let reservoirLevel = newValue.reservoirLevel,
                case .valid(let reservoirRemaining) = reservoirLevel
            {
                delegate?.pumpManager(self,
                                      didReadReservoirValue: Double(reservoirRemaining),
                                      at: self.dateGenerator(),
                                      completion: { _ in })
            }
            
            delegate?.pumpManagerDidUpdateState(self)
        }
        
        log.debug("state updated: %@", String(describing: state))

        return returnValue
    }

    
    private let lockedState: Locked<DashPumpManagerState>

    private func notifyStatusObservers(oldStatus: PumpManagerStatus) {
        let status = self.status

        pumpDelegate.notify { (delegate) in
            delegate?.pumpManager(self, didUpdate: status, oldStatus: oldStatus)
        }
        statusObservers.forEach { (observer) in
            observer.pumpManager(self, didUpdate: status, oldStatus: oldStatus)
        }
    }

    private var device: HKDevice {
        let hardwareVersion: String?
        let firmwareVersion: String?
        let localIdentifier: String?
        if let podVersion = podCommManager.podVersionAbstracted {
            hardwareVersion = "LOT: \(podVersion.lotNumber)"
            firmwareVersion = podVersion.firmwareVersion
            localIdentifier = "SEQ: \(podVersion.sequenceNumber)"
        } else {
            hardwareVersion = nil
            firmwareVersion = nil
            localIdentifier = nil
        }
        
        return HKDevice(
            name: type(of: self).managerIdentifier,
            manufacturer: "Insulet",
            model: "DASH",
            hardwareVersion: hardwareVersion,
            firmwareVersion: firmwareVersion,
            softwareVersion: String(DashKitVersionNumber),
            localIdentifier: localIdentifier,
            udiDeviceIdentifier: nil
        )
    }

    public var status: PumpManagerStatus {
        return status(for: state)
    }

    private var statusObservers = WeakSynchronizedSet<PumpManagerStatusObserver>()

    public func addStatusObserver(_ observer: PumpManagerStatusObserver, queue: DispatchQueue) {
        statusObservers.insert(observer, queue: queue)
    }

    public func removeStatusObserver(_ observer: PumpManagerStatusObserver) {
        statusObservers.removeElement(observer)
    }

    private var podStatusObservers = WeakSynchronizedSet<PodStatusObserver>()

    public func addPodStatusObserver(_ observer: PodStatusObserver, queue: DispatchQueue) {
        podStatusObservers.insert(observer, queue: queue)
    }

    public func removePodStatusObserver(_ observer: PodStatusObserver) {
        podStatusObservers.removeElement(observer)
    }

    public var podActivatedAt: Date? {
        return state.podActivatedAt
    }

    public var podExpiresAt: Date? {
        return state.podActivatedAt?.addingTimeInterval(Pod.lifetime)
    }

    // From last status response
    public var reservoirLevel: ReservoirLevel? {
        return state.reservoirLevel
    }
    
    public var podTotalDelivery: HKQuantity? {
        guard let delivery = state.podTotalDelivery else {
            return nil
        }
        return HKQuantity(unit: .internationalUnit(), doubleValue: delivery)
    }

    public var reservoirWarningLevel: Double {
        return 10 // TODO: Make configurable
    }

    public var isReservoirLow: Bool {
        return false  // TODO
    }

    public var lastStatusDate: Date? {
        return state.lastStatusDate
    }

    public var podCommState: PodCommState {
        return podCommManager.podCommState
    }

    public var isPeriodicStatusCheckConfigured: Bool = false

    public func getPodStatus(completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        podCommManager.getPodStatus(userInitiated: false) { (response) in
            switch response {
            case .failure(let error):
                self.log.error("Fetching status failed: %{public}@", String(describing: error))
            case .success(let status):
                self.log.debug("getPodStatus result: %@", String(describing: status))
                self.mutateState({ (state) in
                    state.updateFromPodStatus(status: status)
                })
            }
            completion(response)
        }
    }

    public func startPodActivation(lowReservoirAlert: LowReservoirAlert, podExpirationAlert: PodExpirationAlert, eventListener: @escaping (ActivationStatus<ActivationStep1Event>) -> ())
    {
        return podCommManager.startPodActivation(lowReservoirAlert: lowReservoirAlert, podExpirationAlert: podExpirationAlert) { (activationStatus) in
            if case .event(let event) = activationStatus, case .podStatus(let status) = event {
                self.mutateState({ (state) in
                    state.updateFromPodStatus(status: status)
                })
            }
            eventListener(activationStatus)
        }
    }

    public func finishPodActivation(autoOffAlert: AutoOffAlert, eventListener: @escaping (ActivationStatus<ActivationStep2Event>) -> ()) {
        let offset = state.timeZone.scheduleOffset(forDate: dateGenerator())
        let programType = ProgramType.basalProgram(basal: state.basalProgram, secondsSinceMidnight: Int(offset.rounded()))
        podCommManager.finishPodActivation(basalProgram: programType, autoOffAlert: autoOffAlert) { (activationStatus) in
            switch activationStatus {
            case .event(let event):
                self.log.debug("finishPodActivation event: %@", String(describing: event))
                switch event {
                case .podStatus(let podStatus):
                    self.mutateState({ (state) in
                        state.updateFromPodStatus(status: podStatus)
                    })
                case .step2Completed:
                    self.mutateState({ (state) in
                        let now = self.dateGenerator()
                        state.finishedDoses.append(UnfinalizedDose(resumeStartTime: now, scheduledCertainty: .certain))
                        state.suspendState = .resumed(now)
                    })
                default:
                    break
                }
            case .error(let error):
                self.log.error("Error from finishPodActivation: %{public}@", String(describing: error))
            }
            self.finalizeAndStoreDoses()
            eventListener(activationStatus)
        }
    }
    
    public func podDeactivated() {
        self.resolveAnyPendingCommandWithUncertainty()
        
        mutateState({ (state) in
            let now = self.dateGenerator()
            state.unfinalizedBolus?.cancel(at: now)
            state.unfinalizedTempBasal?.cancel(at: now)
            state.finalizeDoses()
            state.finishedDoses.append(UnfinalizedDose(suspendStartTime: now, scheduledCertainty: .certain))
            state.suspendState = .suspended(now)
            state.podActivatedAt = nil
            state.lastStatusDate = nil
            state.reservoirLevel = nil
            state.podTotalDelivery = nil
            state.alarmCode = nil
        })
        clearSuspendReminder()
    }
    
    public func discardPod(completion: @escaping (PodCommResult<Bool>) -> ()) {
        podCommManager.discardPod { (result) in
            self.podDeactivated()
            self.finalizeAndStoreDoses(completion: { (_) in
                completion(result)
            })
        }
    }

    public func deactivatePod(completion: @escaping (PodCommResult<PartialPodStatus>) -> ()) {
        podCommManager.deactivatePod { (result) in
            switch result {
            case .success:
                self.podDeactivated()
                self.finalizeAndStoreDoses(completion: { (_) in
                    completion(result)
                })
            default:
                completion(result)
            }
        }
    }

    public func setBasalSchedule(basalProgram: BasalProgram, timeZone: TimeZone, completion: @escaping (Error?) -> Void) {
        guard !state.isSuspended else {
            log.default("Storing basal schedule change locally during suspend")
            self.mutateState { (state) in
                state.basalProgram = basalProgram
            }
            completion(nil)
            return
        }
        
        suspendDelivery { (error) in
            if let error = error {
                completion(error)
                return
            }
            let offset = timeZone.scheduleOffset(forDate: self.dateGenerator())

            self.sendProgram(programType: .basalProgram(basal: basalProgram, secondsSinceMidnight: Int(offset.rounded())), beepOption: .none) { (result) in
                switch result {
                case .failure(let error):
                    completion(DashPumpManagerError(error))
                case .success(let podStatus):
                    let now = self.dateGenerator()
                    self.mutateState({ (state) in
                        state.basalProgram = basalProgram
                        state.updateFromPodStatus(status: podStatus)
                        state.finishedDoses.append(UnfinalizedDose(resumeStartTime: now, scheduledCertainty: .certain))
                        state.timeZone = timeZone
                        state.suspendState = .resumed(now)
                    })
                    completion(nil)
                }
            }
        }
    }

    public func setBasalSchedule(dailyItems: [RepeatingScheduleValue<Double>], completion: @escaping (Error?) -> Void) {
        guard let basalProgram = BasalProgram(items: dailyItems) else {
            completion(DashPumpManagerError.invalidBasalSchedule)
            return
        }
        
        setBasalSchedule(basalProgram: basalProgram, timeZone: self.state.timeZone, completion: completion)
        
    }
    
    public func setMaximumTempBasalRate(_ rate: Double) {
        lockedState.mutate { (state) in
            state.maximumTempBasalRate = rate
        }
    }

    public func setTime(completion: @escaping (Error?) -> Void) {
        setBasalSchedule(basalProgram: state.basalProgram, timeZone: TimeZone.currentFixed, completion: completion)
    }

    private var isPumpDataStale: Bool {
        let pumpStatusAgeTolerance = TimeInterval(minutes: 6)
        let pumpDataAge = -(state.lastStatusDate ?? .distantPast).timeIntervalSince(dateGenerator())
        return pumpDataAge > pumpStatusAgeTolerance
    }

    private func finalizeAndStoreDoses(completion: ((Error?) -> Void)? = nil) {
        var dosesToStore: [UnfinalizedDose] = []

        lockedState.mutate { (state) in
            state.finalizeDoses()

            dosesToStore = state.finishedDoses
            
            if let unfinalizedBolus = state.unfinalizedBolus {
                dosesToStore.append(unfinalizedBolus)
            }
            if let unfinalizedTempBasal = state.unfinalizedTempBasal {
                dosesToStore.append(unfinalizedTempBasal)
            }
        }

        let lastPumpReconciliation = lastReconciliation

        pumpDelegate.notify { (delegate) in
            delegate?.pumpManager(self, hasNewPumpEvents: dosesToStore.map { NewPumpEvent($0, at: self.dateGenerator()) }, lastReconciliation: lastPumpReconciliation, completion: { (error) in
                if let error = error {
                    self.log.error("Error storing pod events: %@", String(describing: error))
                    completion?(error)
                } else {
                    self.lockedState.mutate { (state) in
                        state.finishedDoses.removeAll { dosesToStore.contains($0) }
                    }
                    self.log.default("Stored pod events: %@", String(describing: dosesToStore))
                    completion?(nil)
                }
            })
        }
    }

    public func ensureCurrentPumpData(completion: (() -> Void)?) {

        guard hasActivePod, state.pendingCommand == nil else {
            return
        }

        guard !isPumpDataStale else {
            log.default("Fetching status because pumpData is too old")
            getPodStatus { (response) in
                switch response {
                case .success:
                    self.log.default("Recommending Loop")
                    self.finalizeAndStoreDoses()
                    self.pumpDelegate.notify({ (delegate) in
                        completion?()
                        delegate?.pumpManagerRecommendsLoop(self)
                    })
                case .failure(let error):
                    self.log.default("Not recommending Loop because pump data is stale: %@", String(describing: error))
                    self.pumpDelegate.notify({ (delegate) in
                        completion?()
                        delegate?.pumpManager(self, didError: PumpManagerError.communication(error))
                    })
                }
            }
            return
        }

        pumpDelegate.notify { (delegate) in
            self.log.default("Recommending Loop")
            completion?()
            delegate?.pumpManagerRecommendsLoop(self)
        }
    }

    private func basalDeliveryState(for state: DashPumpManagerState) -> PumpManagerStatus.BasalDeliveryState {
        if podCommManager.podCommState == .noPod {
            return .suspended(state.lastStatusDate ?? .distantPast)
        }
        
        if let transition = state.activeTransition {
            switch transition {
            case .suspendingPump:
                return .suspending
            case .resumingPump:
                return .resuming
            case .cancelingTempBasal:
                return .cancelingTempBasal
            case .startingTempBasal:
                return .initiatingTempBasal
            default:
                break
            }
        }
        
        if let tempBasal = state.unfinalizedTempBasal, !tempBasal.isFinished(at: dateGenerator()) {
            return .tempBasal(DoseEntry(tempBasal, at: dateGenerator()))
        }
        
        switch state.suspendState {
        case .resumed(let date):
            return .active(date)
        case .suspended(let date):
            return .suspended(date)
        }
    }

    private func bolusState(for state: DashPumpManagerState) -> PumpManagerStatus.BolusState {
        if podCommManager.podCommState == .noPod {
            return .none
        }

        if let transition = state.activeTransition {
            switch transition {
            case .startingBolus:
                return .initiating
            case .cancelingBolus:
                return .canceling
            default:
                break
            }
        }
        if let bolus = state.unfinalizedBolus, !bolus.isFinished(at: dateGenerator()) {
            return .inProgress(DoseEntry(bolus, at: dateGenerator()))
        }
        return .none
    }

    public func createBolusProgressReporter(reportingOn dispatchQueue: DispatchQueue) -> DoseProgressReporter? {
        if case .inProgress(let dose) = bolusState(for: self.state) {
            return PodDoseProgressTimerEstimator(dose: dose, pumpManager: self, reportingQueue: dispatchQueue)
        }
        return nil
    }
    
    func sendProgram(programType: ProgramType, beepOption: BeepOption?, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        let commandDate = dateGenerator()
        podCommManager.sendProgram(programType: programType, beepOption: beepOption) { (result) in
            if case .failure(.unacknowledgedCommandPendingRetry) = result {
                self.mutateState { (state) in
                    state.pendingCommand = .program(programType, commandDate)
                }
            }
            completion(result)
        }
    }
    
    func stopProgram(stopProgramType: StopProgramType, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        let commandDate = dateGenerator()
        podCommManager.stopProgram(programType: stopProgramType) { (result) in
            if case .failure(.unacknowledgedCommandPendingRetry) = result {
                self.mutateState { (state) in
                    state.pendingCommand = .stopProgram(stopProgramType, commandDate)
                }
            }
            completion(result)
        }
    }

    public func enactBolus(units: Double, at startDate: Date, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        let preflightError = self.setStateWithResult({ (state) -> PumpManagerError? in
            if state.activeTransition != nil {
                return .deviceState(DashPumpManagerError.busy)
            }
            if let bolus = state.unfinalizedBolus, !bolus.isFinished(at: dateGenerator()) {
                return .deviceState(DashPumpManagerError.busy)
            }
            
            state.activeTransition = .startingBolus
            return nil
        })
        
        guard preflightError == nil else {
            completion(.failure(preflightError!))
            return
        }
        
        // Round to nearest supported volume
        let enactUnits = roundToSupportedBolusVolume(units: units)
        
        guard let bolus = try? Bolus(immediateVolume: Int(round(enactUnits * Pod.podSDKInsulinMultiplier))) else {
            completion(.failure(.configuration(DashPumpManagerError.invalidBolusVolume)))
            return
        }
        
        let program = ProgramType.bolus(bolus: bolus)

        let endDate = startDate.addingTimeInterval(enactUnits / Pod.bolusDeliveryRate)
        let dose = DoseEntry(type: .bolus, startDate: startDate, endDate: endDate, value: enactUnits, unit: .units)

        sendProgram(programType: program, beepOption: nil) { (result) in
            switch result {
            case .success(let podStatus):
                self.mutateState({ (state) in
                    if let finishedBolus = state.unfinalizedBolus {
                        state.finishedDoses.append(finishedBolus)
                    }
                    state.unfinalizedBolus = UnfinalizedDose(bolusAmount: enactUnits, startTime: startDate, scheduledCertainty: .certain)
                    state.updateFromPodStatus(status: podStatus)
                    state.activeTransition = nil
                })
                self.finalizeAndStoreDoses()
                completion(.success(dose))
            case .failure(let error):
                self.mutateState({ (state) in
                    state.activeTransition = nil
                })
                self.finalizeAndStoreDoses()
                if self.state.pendingCommand != nil {
                    completion(.failure(.uncertainDelivery))
                } else {
                    completion(.failure(.communication(DashPumpManagerError(error))))
                }
            }
        }
    }

    public func cancelBolus(completion: @escaping (PumpManagerResult<DoseEntry?>) -> Void) {
        
        let preflightError = self.setStateWithResult({ (state) -> DashPumpManagerError? in
            if state.activeTransition != nil {
                return DashPumpManagerError.busy
            }
            
            state.activeTransition = .cancelingBolus
            return nil
        })
        
        guard preflightError == nil else {
            completion(.failure(.deviceState(preflightError!)))
            return
        }

        podCommManager.stopProgram(programType: .bolus) { (result) in
            switch result {
            case .success(let status):
                self.mutateState({ (state) in
                    state.unfinalizedBolus?.cancel(at: self.dateGenerator(), withRemaining: status.bolusUnitsRemaining)
                    state.updateFromPodStatus(status: status)
                    state.activeTransition = nil
                })
                self.finalizeAndStoreDoses()
                completion(.success(self.state.unfinalizedBolus?.doseEntry(at: self.dateGenerator())))
            case .failure(let error):
                self.mutateState({ (state) in
                    state.activeTransition = nil
                })
                completion(.failure(.communication(DashPumpManagerError(error))))
            }
        }
    }

    public func cancelTempBasal(completion: @escaping (DashPumpManagerError?) -> Void) {
        let preflightError = self.setStateWithResult({ (state) -> DashPumpManagerError? in
            if state.activeTransition != nil {
                return DashPumpManagerError.busy
            }
            
            state.activeTransition = .cancelingTempBasal
            return nil
        })
        
        guard preflightError == nil else {
            completion(preflightError!)
            return
        }

        self.stopProgram(stopProgramType: .tempBasal(reminderBeep: false)) { (result) in
            self.log.debug("stopProgram result: %{public}@", String(describing: result))
            switch result {
            case .success(let status):
                self.mutateState({ (state) in
                    if var canceledTempBasal = state.unfinalizedTempBasal {
                        canceledTempBasal.cancel(at: self.dateGenerator())
                        state.unfinalizedTempBasal = nil
                        state.finishedDoses.append(canceledTempBasal)
                    }
                    state.updateFromPodStatus(status: status)
                    state.activeTransition = nil
                })
                completion(nil)
            case .failure(let error):
                self.mutateState({ (state) in
                    state.activeTransition = nil
                })
                completion(DashPumpManagerError(error))
            }
        }
    }

    public func enactTempBasal(unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        
        // Round to nearest supported volume
        let enactRate = roundToSupportedBasalRate(unitsPerHour: unitsPerHour)
        let program: ProgramType?
        
        do {
            if duration < .ulpOfOne {
                program = nil
            } else {
                let tempBasal = try TempBasal(value: .flatRate(Int(round(enactRate * Pod.podSDKInsulinMultiplier))), duration: duration)
                // secondsSinceMidnight not used for absolute rate temp basals; SDK api will change in future so this is only specified for percent value types
                program = ProgramType.tempBasal(tempBasal: tempBasal)
            }
        } catch {
            completion(.failure(.configuration(DashPumpManagerError.invalidTempBasalRate)))
            return
        }
        
        let preflight: (_ completion: @escaping (DashPumpManagerError?) -> Void) -> Void
        
        if case .tempBasal = status.basalDeliveryState {
            preflight = { (_ completion: @escaping (DashPumpManagerError?) -> Void) in
                self.cancelTempBasal { (error) in
                    if let error = error {
                        self.log.error("cancelTempBasal error: %{public}@", String(describing: error))
                        completion(error)
                    } else {
                        self.log.default("cancelTempBasal succeeded")
                        completion(nil)
                    }
                }
            }
        } else {
            preflight = { (_ completion: @escaping (DashPumpManagerError?) -> Void) in
                self.podCommManager.getPodStatus(userInitiated: false) { (result) in
                    switch result {
                    case .failure(let error):
                        self.log.error("getPodStatus error: %{public}@", String(describing: error))
                        completion(DashPumpManagerError(error))
                    case .success:
                        completion(nil)
                    }
                }
            }
        }
        
        preflight { (error) in
            if let error = error {
                completion(.failure(.configuration(error)))
            } else {
                self.log.default("preflight succeeded")
                guard let program = program else {
                    // 0 duration temp basals are used to cancel any existing temp basal
                    let date = self.dateGenerator()
                    self.finalizeAndStoreDoses()
                    completion(.success(DoseEntry(type: .tempBasal, startDate: date, endDate: date, value: 0, unit: .unitsPerHour)))
                    return
                }
                
                let preflightError = self.setStateWithResult({ (state) -> DashPumpManagerError? in
                    if state.activeTransition != nil {
                        return DashPumpManagerError.busy
                    }
                    
                    state.activeTransition = .startingTempBasal
                    return nil
                })
                
                guard preflightError == nil else {
                    completion(.failure(.communication(preflightError!)))
                    return
                }
                
                let startDate = self.dateGenerator()
                
                let dose = DoseEntry(type: .tempBasal, startDate: startDate, endDate: startDate.addingTimeInterval(duration), value: enactRate, unit: .unitsPerHour)
                
                // SDK not allowing us to make calls from a callback thread, so dispatch.
                DispatchQueue.global(qos: .userInteractive).async {
                    self.sendProgram(programType: program, beepOption: .init(beepAtEnd: false)) { (result) in
                        switch result {
                        case .failure(let error):
                            self.mutateState({ (state) in
                                state.activeTransition = nil
                            })
                            self.finalizeAndStoreDoses()
                            if self.state.pendingCommand != nil {
                                completion(.failure(.uncertainDelivery))
                            } else {
                                completion(.failure(.communication(DashPumpManagerError(error))))
                            }
                        case .success(let podStatus):
                            self.mutateState({ (state) in
                                state.unfinalizedTempBasal = UnfinalizedDose(tempBasalRate: enactRate, startTime: startDate, duration: duration, scheduledCertainty: .certain)
                                state.updateFromPodStatus(status: podStatus)
                                state.activeTransition = nil
                            })
                            self.finalizeAndStoreDoses()
                            completion(.success(dose))
                        }
                    }
                }
            }
        }
    }

    public func setMustProvideBLEHeartbeat(_ mustProvideBLEHeartbeat: Bool) {
        if mustProvideBLEHeartbeat && !isPeriodicStatusCheckConfigured {
            self.log.debug("podCommManager periodic status: configuring")
            podCommManager.configPeriodicStatusCheck(interval: .minutes(1)) { (result) in
                switch result {
                case .failure(let error):
                    self.log.error("podCommManager periodic status check error: %{public}@", String(describing: error))
                case .success(let status):
                    self.isPeriodicStatusCheckConfigured = true
                    self.log.debug("podCommManager periodic status check configured", String(describing: status))
                }
            }
        }
    }

    public func suspendDelivery(completion: @escaping (Error?) -> Void) {
        let reminder = try! StopProgramReminder(value: StopProgramReminder.maxSuspendDuration)
        suspendDelivery(withReminder: reminder, completion: completion)
    }

    public func suspendDelivery(withReminder reminder: StopProgramReminder, completion: @escaping (DashPumpManagerError?) -> Void) {
        
        let preflightError = self.setStateWithResult({ (state) -> DashPumpManagerError? in
            if state.activeTransition != nil {
                return DashPumpManagerError.busy
            }
            state.activeTransition = .suspendingPump
            return nil
        })
        
        guard preflightError == nil else {
            completion(preflightError!)
            return
        }

        stopProgram(stopProgramType: .stopAll(reminder: reminder)) { (result) in
            switch result {
            case .failure(let error):
                self.mutateState({ (state) in
                    state.activeTransition = nil
                })
                completion(DashPumpManagerError(error))
            case .success(let podStatus):

                self.mutateState({ (state) in
                    let now = self.dateGenerator()
                    if let unfinalizedTempBasal = state.unfinalizedTempBasal,
                        let finishTime = unfinalizedTempBasal.endTime,
                        finishTime > now
                    {
                        state.unfinalizedTempBasal?.cancel(at: now)
                    }
                    
                    if let unfinalizedBolus = state.unfinalizedBolus,
                        let finishTime = unfinalizedBolus.endTime,
                        finishTime > now
                    {
                        state.unfinalizedBolus?.cancel(at: now, withRemaining: podStatus.bolusUnitsRemaining)
                        self.log.info("Interrupted bolus: %@", String(describing: state.unfinalizedBolus))
                    }
                    
                    state.finishedDoses.append(UnfinalizedDose(suspendStartTime: now, scheduledCertainty: .certain))
                    state.suspendState = .suspended(now)
                    state.updateFromPodStatus(status: podStatus)
                    state.activeTransition = nil
                })

                self.finalizeAndStoreDoses()
                completion(nil)
            }
        }
    }

    fileprivate func clearSuspendReminder() {
        self.pumpDelegate.notify { (delegate) in
            delegate?.retractAlert(identifier: Alert.Identifier(managerIdentifier: self.managerIdentifier, alertIdentifier: PodAlert.suspendEnded.alertIdentifier))
            delegate?.retractAlert(identifier: Alert.Identifier(managerIdentifier: self.managerIdentifier, alertIdentifier: PodAlert.suspendEnded.repeatingAlertIdentifier))
        }
    }

    public func resumeDelivery(completion: @escaping (Error?) -> Void) {
        self.resumeInsulinDelivery(completion: completion)
    }

    public func resumeInsulinDelivery(completion: @escaping (DashPumpManagerError?) -> Void) {
        let preflightError = self.setStateWithResult({ (state) -> DashPumpManagerError? in
            if state.activeTransition != nil {
                return DashPumpManagerError.busy
            }
            state.activeTransition = .resumingPump
            return nil
        })
        
        guard preflightError == nil else {
            completion(preflightError!)
            return
        }
        
        let offset = state.timeZone.scheduleOffset(forDate: dateGenerator())
        let programType = ProgramType.basalProgram(basal: state.basalProgram, secondsSinceMidnight: Int(offset.rounded()))

        sendProgram(programType: programType, beepOption: .none) { (result) in
            switch result {
            case .failure(let error):
                self.mutateState({ (state) in
                    state.activeTransition = nil
                })
                completion(DashPumpManagerError(error))
            case .success(let podStatus):
                self.clearSuspendReminder()
                self.mutateState({ (state) in
                    let now = self.dateGenerator()
                    state.finishedDoses.append(UnfinalizedDose(resumeStartTime: now, scheduledCertainty: .certain))
                    state.suspendState = .resumed(now)
                    state.updateFromPodStatus(status: podStatus)
                    state.activeTransition = nil
                })
                self.finalizeAndStoreDoses()
                completion(nil)
            }
        }
    }

    public func syncBasalRateSchedule(items scheduleItems: [RepeatingScheduleValue<Double>], completion: @escaping (Result<BasalRateSchedule, Error>) -> Void) {
        setBasalSchedule(dailyItems: scheduleItems) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(BasalRateSchedule(dailyItems: scheduleItems, timeZone: self.state.timeZone)!))
            }
        }
    }
    
    // Reconnected to the pod, and we know program was successful
    private func pendingCommandSucceeded(pendingCommand: PendingCommand, podStatus: PodStatus) {
        self.mutateState { (state) in
            switch pendingCommand {
            case .program(let program, let commandDate):
                if let dose = program.unfinalizedDose(at: commandDate, withCertainty: .certain) {
                    if dose.isFinished(at: dateGenerator()) {
                        state.finishedDoses.append(dose)
                        if case .resume = dose.doseType {
                            state.suspendState = .resumed(commandDate)
                        }
                    } else {
                        switch dose.doseType {
                        case .bolus:
                            state.unfinalizedBolus = dose
                        case .tempBasal:
                            state.unfinalizedTempBasal = dose
                        default:
                            break
                        }
                    }
                    state.updateFromPodStatus(status: podStatus)
                }
            case .stopProgram(let stopProgram, let commandDate):
                var bolusCancel = false
                var tempBasalCancel = false
                var didSuspend = false
                switch stopProgram {
                case .bolus:
                    bolusCancel = true
                case .tempBasal:
                    tempBasalCancel = true
                case .stopAll:
                    bolusCancel = true
                    tempBasalCancel = true
                    didSuspend = true
                }
                
                if bolusCancel, let bolus = state.unfinalizedBolus, !bolus.isFinished(at: commandDate) {
                    state.unfinalizedBolus?.cancel(at: commandDate, withRemaining: podStatus.bolusUnitsRemaining)
                }
                if tempBasalCancel, let tempBasal = state.unfinalizedTempBasal, !tempBasal.isFinished(at: commandDate) {
                    state.unfinalizedTempBasal?.cancel(at: commandDate)
                }
                if didSuspend {
                    state.finishedDoses.append(UnfinalizedDose(suspendStartTime: commandDate, scheduledCertainty: .certain))
                    state.suspendState = .suspended(commandDate)
                }
                state.updateFromPodStatus(status: podStatus)
            }
        }
        self.finalizeAndStoreDoses()
    }

    // Reconnected to the pod, and we know program was not received
    private func pendingCommandFailed(pendingCommand: PendingCommand, podStatus: PodStatus) {
        // Nothing to do besides update using the pod status, because we already responded to Loop as if the commands failed.
        self.mutateState({ (state) in
            state.updateFromPodStatus(status: podStatus)
        })
        self.finalizeAndStoreDoses()
    }
    
    // Giving up on pod; we will assume commands failed/succeeded in the direction of positive net delivery
    private func resolveAnyPendingCommandWithUncertainty() {
        guard let pendingCommand = state.pendingCommand else {
            return
        }
        
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = state.timeZone
        
        self.mutateState { (state) in
            switch pendingCommand {
            case .program(let program, let commandDate):
                let scheduledSegmentAtCommandTime = state.basalProgram.currentRate(using: calendar, at: commandDate)

                if let dose = program.unfinalizedDose(at: commandDate, withCertainty: .uncertain) {
                    switch dose.doseType {
                    case .bolus:
                        if dose.isFinished(at: dateGenerator()) {
                            state.finishedDoses.append(dose)
                        } else {
                            state.unfinalizedBolus = dose
                        }
                    case .tempBasal:
                        // Assume a high temp succeeded, but low temp failed
                        let rate = dose.programmedRate ?? dose.rate
                        if rate > scheduledSegmentAtCommandTime.basalRateUnitsPerHour {
                            if dose.isFinished(at: dateGenerator()) {
                                state.finishedDoses.append(dose)
                            } else {
                                state.unfinalizedTempBasal = dose
                            }
                        }
                    case .resume:
                        state.finishedDoses.append(dose)
                    case .suspend:
                        break // start program is never a suspend
                    }
                }
            case .stopProgram(let stopProgram, let commandDate):
                let scheduledSegmentAtCommandTime = state.basalProgram.currentRate(using: calendar, at: commandDate)
                
                // All stop programs result in reduced delivery, except for stopping a low temp, so we assume all stop
                // commands failed, except for low temp
                var tempBasalCancel = false

                switch stopProgram {
                case .tempBasal:
                    tempBasalCancel = true
                case .stopAll:
                    tempBasalCancel = true
                default:
                    break
                }
                
                if tempBasalCancel,
                    let tempBasal = state.unfinalizedTempBasal,
                    !tempBasal.isFinished(at: commandDate),
                    (tempBasal.programmedRate ?? tempBasal.rate) < scheduledSegmentAtCommandTime.basalRateUnitsPerHour
                {
                    state.unfinalizedTempBasal?.cancel(at: commandDate)
                }
            }
            state.pendingCommand = nil
        }
    }

    public func attemptUnacknowledgedCommandRecovery() {
        if let pendingCommand = self.state.pendingCommand {
            podCommManager.queryAndClearUnacknowledgedCommand { (result) in
                switch result {
                case .success(let retryResult):
                    if retryResult.hasPendingCommandProgrammed {
                        self.pendingCommandSucceeded(pendingCommand: pendingCommand, podStatus: retryResult.status)
                    } else {
                        self.pendingCommandFailed(pendingCommand: pendingCommand, podStatus: retryResult.status)
                    }
                    self.mutateState { (state) in
                        state.pendingCommand = nil
                    }
                case .failure:
                    break
                }
            }
        }
    }

    public init(state: DashPumpManagerState, podCommManager: PodCommManagerProtocol? = nil, dateGenerator: @escaping () -> Date = Date.init) {
        
        let loggingShim: PodSDKLoggingShim
        let actualPodCommManager: PodCommManagerProtocol

        #if targetEnvironment(simulator)
        let mockPodCommManager = MockPodCommManager.shared
        if let reservoirUnitsRemaining = state.reservoirLevel?.rawValue {
            mockPodCommManager.podStatus.reservoirUnitsRemaining = reservoirUnitsRemaining
        }
        #endif

        if let podCommManager = podCommManager {
            actualPodCommManager = podCommManager
        } else {
            #if targetEnvironment(simulator)
            actualPodCommManager = mockPodCommManager
            #else
            actualPodCommManager = PodCommManager.shared
            #endif
        }
        loggingShim = PodSDKLoggingShim(target: actualPodCommManager)
        
        loggingShim.deviceIdentifier = actualPodCommManager.deviceIdentifier

        self.lockedState = Locked(state)
        self.podCommManager = loggingShim
        self.dateGenerator = dateGenerator
        
        loggingShim.loggingShimDelegate = self

        self.podCommManager.delegate = self
        
        actualPodCommManager.setLogger(logger: self)

        actualPodCommManager.setup(withLaunchingOptions: [:])
        
        #if targetEnvironment(simulator)
        mockPodCommManager.dashPumpManager = self
        #endif
    }

    public convenience required init?(rawState: PumpManager.RawStateValue) {
        guard let state = DashPumpManagerState(rawValue: rawState) else
        {
            return nil
        }

        self.init(state: state)
    }

    public var rawState: PumpManager.RawStateValue {
        return state.rawValue
    }
    
    public var sdkVersion: String {
        Bundle(for: PodCommManager.self).infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
    
    public var podVersion: PodVersionProtocol? {
        return podCommManager.podVersionAbstracted
    }
    
    public var pdmIdentifier: String? {
        return podCommManager.retrievePDMId()
    }

    public var debugDescription: String {
        var lines = [
            "## DashPumpManager",
            "* PodSDK Version: \(sdkVersion)",
            "* PodSDK Build: \(PodSDKVersionNumber)",
            "* podCommState: \(podCommManager.podCommState)",
        ]
        
        if let version = podCommManager.podVersionAbstracted {
            lines.append(contentsOf: [
                "* Pod Lot Number: \(version.lotNumber))",
                "* Pod Sequence Number: \(version.sequenceNumber)",
                "* Pod Firmware Version: \(version.firmwareVersion)"
            ])
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        podCommManager.getPodStatus(userInitiated: false) { (result) in
            switch result {
            case .failure(let error):
                lines.append("* podStatus: Error: \(error)")
            case .success(let status):
                lines.append(contentsOf: [
                    "* activeAlerts: \(status.activeAlerts)",
                    "* bolusRemaining: \(status.bolusRemaining)",
                    "* bolusUnitsRemaining: \(status.bolusUnitsRemaining)",
                    "* delivered: \(status.delivered)",
                    "* expirationDate: \(status.expirationDate)",
                    "* isOcclusionAlertActive: \(status.isOcclusionAlertActive)",
                    "* podState: \(status.podState)",
                    "* programStatus: \(status.programStatus)",
                    "* reservoir: \(status.reservoir)",
                    "* reservoirUnitsRemaining: \(status.reservoirUnitsRemaining)",
                    "* totalUnitsDelivered: \(status.totalUnitsDelivered)",
                ])
            }
            semaphore.signal()
        }
        let result = semaphore.wait(timeout: .now() + .seconds(8))
        if case .timedOut = result {
            lines.append("* podStatus: timed out")
        }
        lines.append(contentsOf: [
            state.debugDescription,
            "",
        ])
        return lines.joined(separator: "\n")
    }
}

// MARK: - LoggingProtocol

// Capture dash logs
extension DashPumpManager: LoggingProtocol {
    public func info(_ message: String) {
        log.default("PodSDK Info: %{public}@", message)
    }

    public func debug(_ message: String) {
        log.default("PodSDK Debug: %{public}@", message)
    }

    public func error(_ message: String) {
        log.default("PodSDK Error: %{public}@", message)
    }
}

// MARK: - PodCommManagerDelegate

extension DashPumpManager: PodCommManagerDelegate {
    private func logPodCommManagerDelegateMessage(_ message: String) {
        self.pumpDelegate.notify { (delegate) in
            delegate?.deviceManager(self, logEventForDeviceIdentifier: self.podCommManager.deviceIdentifier, type: .delegate, message: message, completion: nil)
        }
    }
    
    public func podCommManager(_ podCommManager: PodCommManager, hasSystemError error: SystemError) {
        logPodCommManagerDelegateMessage("hasSystemError: \(String(describing: error))")
    }
    
    private func shouldIgnorePodAlert(_ alert: PodAlert) -> Bool {
        // Ignore podExpiring alert during activation.
        if case .podExpiring = alert, podCommManager.podCommState == .activating {
            return true
        }
        return alert.isIgnored
    }

    // Add additional optional signature for this method for testing, as PodCommManager cannot be instantiate on the simulator
    public func podCommManagerHasAlerts(_ alerts: PodAlerts) {
        logPodCommManagerDelegateMessage("hasAlerts: \(String(describing: alerts))")
        
        let newAlerts = alerts.subtracting(self.state.activeAlerts)
        
        if !newAlerts.isEmpty {
            for alert in newAlerts.allPodAlerts {
                if !shouldIgnorePodAlert(alert) {
                    let identifier = Alert.Identifier(managerIdentifier: self.managerIdentifier, alertIdentifier: alert.alertIdentifier)
                    let loopAlert = Alert(identifier: identifier, foregroundContent: alert.foregroundContent, backgroundContent: alert.backgroundContent, trigger: .immediate)
                    pumpDelegate.notify { (delegate) in
                        delegate?.issueAlert(loopAlert)
                    }
                    
                    if let repeatInterval = alert.repeatInterval {
                        // Schedule an additional repeating 15 minute reminder for suspend period ended.
                        let repeatingIdentifier = Alert.Identifier(managerIdentifier: self.managerIdentifier, alertIdentifier: alert.repeatingAlertIdentifier)
                        let loopAlert = Alert(identifier: repeatingIdentifier, foregroundContent: alert.foregroundContent, backgroundContent: alert.backgroundContent, trigger: .repeating(repeatInterval: repeatInterval))
                        pumpDelegate.notify { (delegate) in
                            delegate?.issueAlert(loopAlert)
                        }
                    }
                }
            }
        }
        
        let clearedAlerts = self.state.activeAlerts.subtracting(alerts)
        if !clearedAlerts.isEmpty {
            for alert in clearedAlerts.allPodAlerts {
                if !alert.isIgnored {
                    pumpDelegate.notify { (delegate) in
                        let identifier = Alert.Identifier(managerIdentifier: self.managerIdentifier, alertIdentifier: alert.alertIdentifier)
                        delegate?.retractAlert(identifier: identifier)
                    }
                    if alert.isRepeating {
                        let repeatingIdentifier = Alert.Identifier(managerIdentifier: self.managerIdentifier, alertIdentifier: alert.repeatingAlertIdentifier)
                        pumpDelegate.notify { (delegate) in
                            delegate?.retractAlert(identifier: repeatingIdentifier)
                        }
                    }
                }
            }
        }
        
        self.mutateState { (state) in
            state.activeAlerts = alerts
        }
    }

    public func podCommManager(_ podCommManager: PodCommManager, hasAlerts alerts: PodAlerts) {
        podCommManagerHasAlerts(alerts)
    }

    public func podCommManager(_ podCommManager: PodCommManagerProtocol, didAlarm alarm: PodAlarm) {
        logPodCommManagerDelegateMessage("didAlarm: \(String(describing: alarm))")
        
        self.mutateState { (state) in
            if let alarmDetail = alarm as? PodAlarmDetail {
                if alarmDetail.alarmTime == nil {
                    log.error("Pod alarm failed to include time of alarm. Using current time as time of alarm.")
                }
                let alarmTime = alarmDetail.alarmTime ?? self.dateGenerator()
                state.alarmCode = alarm.alarmCode
                state.unfinalizedTempBasal?.cancel(at: alarmTime)
                state.suspendState = .suspended(alarmTime)
                if let podStatus = alarmDetail.podStatus as? PodStatus {
                    state.unfinalizedBolus?.cancel(at: alarmTime, withRemaining: podStatus.bolusUnitsRemaining)
                    state.updateFromPodStatus(status: podStatus)
                } else {
                    log.error("Partial status for pod returned with alarm.")
                    state.unfinalizedBolus?.cancel(at: alarmTime)
                }
            } else {
                log.error("Pod alarm did not include alarm details. Using current time to mark delivery suspended.")
                let alarmTime = dateGenerator()
                state.unfinalizedBolus?.cancel(at: alarmTime)
                state.unfinalizedTempBasal?.cancel(at: alarmTime)
            }
        }

        pumpDelegate.notify { delegate in
            let content = Alert.Content(title: alarm.alarmCode.notificationTitle,
                                              body: alarm.alarmCode.notificationBody,
                                              acknowledgeActionButtonLabel: LocalizedString("OK", comment: "Alert acknowledgment OK button"))
            delegate?.issueAlert(Alert(identifier: Alert.Identifier(managerIdentifier: DashPumpManager.podAlarmNotificationIdentifier,
                                                                                alertIdentifier: alarm.alarmCode.rawValue),
                                             foregroundContent: content, backgroundContent: content,
                                             trigger: .immediate))
        }
        
        self.finalizeAndStoreDoses()
    }
    
    public func podCommManager(_ podCommManager: PodCommManager, didAlarm alarm: PodAlarm) {
        self.podCommManager(podCommManager as PodCommManagerProtocol, didAlarm: alarm)
    }
    
    public func podCommManager(_ podCommManager: PodCommManager, didCheckPeriodicStatus status: PodStatus) {
        logPodCommManagerDelegateMessage("didCheckPeriodicStatus: \(String(describing: status))")

        self.pumpDelegate.notify({ (delegate) in
            delegate?.pumpManagerBLEHeartbeatDidFire(self)
        })
    }
    
    public func podCommManager(_ podCommManager: PodCommManager, hasSystemError error: SystemErrorCode) {
        logPodCommManagerDelegateMessage("hasSystemError: \(String(describing: error))")
    }
    
    public func podCommManager(_ podCommManager: PodCommManager, podCommStateDidChange podCommState: PodCommState) {
        logPodCommManagerDelegateMessage("podCommStateDidChange: \(String(describing: podCommState))")
    }
    
    public func podCommManager(_ podCommManager: PodCommManagerProtocol, connectionStateDidChange connectionState: ConnectionState) {
        // TODO: log this as a connection event.
        logPodCommManagerDelegateMessage("connectionStateDidChange: \(String(describing: connectionState))")
        
        if connectionState == .connected && state.pendingCommand != nil {
            attemptUnacknowledgedCommandRecovery()
        }
        
        self.mutateState { (state) in
            state.connectionState = connectionState
        }
    }
    
    public func podCommManager(_ podCommManager: PodCommManager, connectionStateDidChange connectionState: ConnectionState) {
        self.podCommManager(podCommManager as PodCommManagerProtocol, connectionStateDidChange: connectionState)
    }

}

extension DashPumpManager: PodSDKLoggingShimDelegate {
    func podSDKLoggingShim(_ shim: PodSDKLoggingShim, didLogEventForDevice deviceIdentifier: String?, type: DeviceLogEntryType, message: String, completion: ((Error?) -> Void)?) {
        self.pumpDelegate.notify { (delegate) in
            delegate?.deviceManager(self, logEventForDeviceIdentifier: deviceIdentifier, type: type, message: message, completion: nil)
        }
    }
}

// MARK: - AlertResponder implementation
extension DashPumpManager {
    public func acknowledgeAlert(alertIdentifier: Alert.AlertIdentifier) {
        guard let podAlert = PodAlert(rawValue: alertIdentifier) else {
            return
        }
        
        if state.activeAlerts.contains(podAlert.podAlerts) {
            podCommManager.silenceAlerts(alert: podAlert.podAlerts) { (result) in
                switch result {
                case .success(let status):
                    self.mutateState { (state) in
                        state.activeAlerts = status.activeAlerts
                    }
                case .failure:
                    // already logged
                    break
                }
            }
        }
    }
}

// MARK: - AlertSoundVendor implementation
extension DashPumpManager {
    public func getSoundBaseURL() -> URL? { return nil }
    public func getSounds() -> [Alert.Sound] { return [] }
}

