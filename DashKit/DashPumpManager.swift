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

    let podCommManager: PodCommManagerProtocol

    public let log = OSLog(category: "DashPumpManager")

    public static let localizedTitle = LocalizedString("Omnipod DASH", comment: "Generic title of the omnipod DASH pump manager")

    public func roundToSupportedBasalRate(unitsPerHour: Double) -> Double {
         return supportedBasalRates.filter({$0 <= unitsPerHour}).max() ?? 0
    }

    public func roundToSupportedBolusVolume(units: Double) -> Double {
        return supportedBolusVolumes.filter({$0 <= units}).max() ?? 0
    }

    public var supportedBolusVolumes: [Double] {
        // 0.05 units for rates between 0.05-30U/hr
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

    public var pumpRecordsBasalProfileStartEvents = false

    public var pumpReservoirCapacity: Double {
        return Pod.reservoirCapacity
    }

    public var hasActivePod: Bool {
        return state.podActivatedAt != nil
    }

    private func status(for state: DashPumpManagerState) -> PumpManagerStatus {
        return PumpManagerStatus(
            timeZone: state.timeZone,
            device: device(for: state),
            pumpBatteryChargeRemaining: nil,
            basalDeliveryState: basalDeliveryState(for: state),
            bolusState: bolusState(for: state)
        )
    }

    private func device(for state: DashPumpManagerState) -> HKDevice {
        return HKDevice(
            name: type(of: self).managerIdentifier,
            manufacturer: "Insulet",
            model: "DASH",
            hardwareVersion: nil,
            firmwareVersion: nil,
            softwareVersion: String(DashKitVersionNumber),
            localIdentifier: podCommManager.getPodId(),
            udiDeviceIdentifier: nil
        )
    }

    private(set) public var state: DashPumpManagerState {
        get {
            return lockedState.value
        }
        set {
            let oldValue = lockedState.value
            lockedState.value = newValue

            // PumpManagerStatus may have changed
            let oldStatus = status(for: oldValue)
            let newStatus = status(for: state)

            if oldStatus != newStatus {
                notifyStatusObservers(oldStatus: oldStatus)
            }

            if oldValue != newValue {
                pumpDelegate.notify { (delegate) in
                    delegate?.pumpManagerDidUpdateState(self)
                }
            }
        }
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
        return HKDevice(
            name: type(of: self).managerIdentifier,
            manufacturer: "Insulet",
            model: "DASH",
            hardwareVersion: nil,
            firmwareVersion: "1.0",
            softwareVersion: String(DashKitVersionNumber),
            localIdentifier: podCommManager.getPodId(),
            udiDeviceIdentifier: nil
        )
    }

    public var status: PumpManagerStatus {
        return status(for: state)
    }

    private var statusObservers = WeakSynchronizedSet<PumpManagerStatusObserver>()

    public func addStatusObserver(_ observer: PumpManagerStatusObserver, queue: DispatchQueue) {
        self.statusObservers.insert(observer, queue: queue)
    }

    public func removeStatusObserver(_ observer: PumpManagerStatusObserver) {
        self.statusObservers.removeElement(observer)
    }

    private var podStatusObservers = WeakSynchronizedSet<PodStatusObserver>()

    public func addPodStatusObserver(_ observer: PodStatusObserver, queue: DispatchQueue) {
        self.podStatusObservers.insert(observer, queue: queue)
    }

    public func removePodStatusObserver(_ observer: PodStatusObserver) {
        self.podStatusObservers.removeElement(observer)
    }

    private func notifyPodStatusObservers() {
        podStatusObservers.forEach { (observer) in
            observer.didUpdatePodStatus()
        }
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

    public var reservoirWarningLevel: Double {
        return 10 // TODO: Make configurable
    }

    public var isReservoirLow: Bool {
        return false  // TODO
    }

    public var isPodAlarming: Bool {
        return false // TODO
    }

    public var lastStatusDate: Date? {
        return state.lastStatusDate
    }

    public var podCommState: PodCommState {
        return podCommManager.podCommState
    }

    public var podId: String? {
        return podCommManager.getPodId()
    }

    private func updateStateFromPodStatus(status: PodStatusProtocol) {
        lockedState.mutate { (state) in
            state.lastStatusDate = Date()
            state.reservoirLevel = ReservoirLevel(rawValue: status.reservoirUnitsRemaining)
            state.podActivatedAt = status.activationTime
        }
        notifyPodStatusObservers()
    }

    public func getPodStatus(completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) {
        podCommManager.getPodStatus { (response) in
            switch response {
            case .failure(let error):
                print("Error fetching status: \(error)")
            case .success(let status):
                self.updateStateFromPodStatus(status: status)
            }
            completion(response)
        }
    }

    public func startPodActivation(lowReservoirAlert: LowReservoirAlert?, podExpirationAlert: PodExpirationAlert?, eventListener: @escaping (ActivationStatus<ActivationStep1Event>) -> ())
    {

        print("Going to startPodActivation. Registration status = \(RegistrationManager.shared.isRegistered())")
        return podCommManager.startPodActivation(lowReservoirAlert: lowReservoirAlert, podExpirationAlert: podExpirationAlert) { (activationStatus) in
            print("ActivationStatus: \(activationStatus)")
            if case .event(let event) = activationStatus, case .podStatus(let status) = event {
                self.updateStateFromPodStatus(status: status)
            }
            eventListener(activationStatus)
        }
    }

    public func finishPodActivation(basalProgram: BasalProgram, autoOffAlert: AutoOffAlert?, eventListener: @escaping (ActivationStatus<ActivationStep2Event>) -> ()) {
        podCommManager.finishPodActivation(basalProgram: basalProgram, autoOffAlert: autoOffAlert) { (activationStatus) in
            if case .event(let event) = activationStatus, case .podStatus(let status) = event {
                self.updateStateFromPodStatus(status: status)
            }
            eventListener(activationStatus)
        }
    }

    public func discardPod(completion: @escaping (PodCommResult<Bool>) -> ()) {
        podCommManager.discardPod { (result) in
            self.state.podActivatedAt = nil
            self.state.lastStatusDate = nil
            self.state.reservoirLevel = nil
            self.notifyPodStatusObservers()
            completion(result)
        }
    }

    public func deactivatePod(completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) {
        podCommManager.deactivatePod { (result) in
            completion(result)
        }
    }

    private var isPumpDataStale: Bool {
        let pumpStatusAgeTolerance = TimeInterval(minutes: 6)
        let pumpDataAge = -(state.lastStatusDate ?? .distantPast).timeIntervalSinceNow
        return pumpDataAge > pumpStatusAgeTolerance
    }

    private func finalizeAndStoreDoses() {
        var dosesToStore: [UnfinalizedDose] = []

        lockedState.mutate { (state) in
            if let bolus = state.unfinalizedBolus, bolus.finished {
                state.finalizedDoses.append(bolus)
                state.unfinalizedBolus = nil
            }

            if let tempBasal = state.unfinalizedTempBasal, tempBasal.finished {
                state.finalizedDoses.append(tempBasal)
                state.unfinalizedTempBasal = nil
            }

            dosesToStore = state.finalizedDoses
            if let unfinalizedTempBasal = state.unfinalizedTempBasal {
                dosesToStore.append(unfinalizedTempBasal)
            }
            if let unfinalizedSuspend = state.unfinalizedSuspend {
                dosesToStore.append(unfinalizedSuspend)
            }
        }

        guard !dosesToStore.isEmpty else {
            return
        }

        pumpDelegate.notify { (delegate) in
            delegate?.pumpManager(self, didReadPumpEvents: dosesToStore.map { NewPumpEvent($0) }, completion: { (error) in
                if let error = error {
                    self.log.error("Error storing pod events: %@", String(describing: error))
                } else {
                    self.state.finalizedDoses.removeAll()
                    self.log.error("Stored pod events: %@", String(describing: dosesToStore))
                }
            })
        }
    }

    

    public func assertCurrentPumpData() {

        finalizeAndStoreDoses()

        guard hasActivePod else {
            return
        }

        guard !isPumpDataStale else {
            log.default("Fetching status because pumpData is too old")
            getPodStatus { (response) in
                self.pumpDelegate.notify({ (delegate) in
                    switch response {
                    case .success:
                        self.log.default("Recommending Loop")
                        delegate?.pumpManagerRecommendsLoop(self)
                    case .failure(let error):
                        self.log.default("Not recommending Loop because pump data is stale: %@", String(describing: error))
                        delegate?.pumpManager(self, didError: PumpManagerError.communication(error))
                    }
                })
            }
            return
        }

        pumpDelegate.notify { (delegate) in
            self.log.default("Recommending Loop")
            delegate?.pumpManagerRecommendsLoop(self)
        }
    }

    private func basalDeliveryState(for state: DashPumpManagerState) -> PumpManagerStatus.BasalDeliveryState {

        switch state.suspendTransition {
        case .suspending?:
            return .suspending
        case .resuming?:
            return .resuming
        case .none:
            return state.suspended ? .suspended : .active
        }
    }

    private func bolusState(for state: DashPumpManagerState) -> PumpManagerStatus.BolusState {

        switch state.bolusTransition {
        case .initiating?:
            return .initiating
        case .canceling?:
            return .canceling
        case .none:
            if let bolus = state.unfinalizedBolus, !bolus.finished {
                return .inProgress(DoseEntry(bolus))
            } else {
                return .none
            }
        }
    }

    public func createBolusProgressReporter(reportingOn dispatchQueue: DispatchQueue) -> DoseProgressReporter? {
        if case .inProgress(let dose) = bolusState(for: self.state) {
            return PodDoseProgressEstimator(dose: dose, pumpManager: self, reportingQueue: dispatchQueue)
        }
        return nil
    }

    public func enactBolus(units: Double, at startDate: Date, willRequest: @escaping (DoseEntry) -> Void, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        do {
            // Round to nearest supported volume
            let enactUnits = roundToSupportedBolusVolume(units: units)
            let program = ProgramType.bolus(bolus: try Bolus(immediateVolume: Int(round(enactUnits * 100))))

            let endDate = startDate.addingTimeInterval(enactUnits / Pod.bolusDeliveryRate)
            let dose = DoseEntry(type: .bolus, startDate: startDate, endDate: endDate, value: enactUnits, unit: .units)

            willRequest(dose)

            self.state.bolusTransition = .initiating

            podCommManager.sendProgram(programType: program, beepOption: nil) { (result) in
                switch(result) {
                case .success(let podStatus):
                    self.state.unfinalizedBolus = UnfinalizedDose(bolusAmount: enactUnits, startTime: startDate, scheduledCertainty: .certain)
                    self.updateStateFromPodStatus(status: podStatus)
                    self.state.bolusTransition = nil
                    completion(.success(dose))
                case .failure(let error):
                    self.state.bolusTransition = nil
                    completion(.failure(error))
                }
            }
        } catch let error {
            completion(.failure(error))
        }
    }

    public func cancelBolus(completion: @escaping (PumpManagerResult<DoseEntry?>) -> Void) {
        podCommManager.stopProgram(programType: .bolus) { (result) in
            switch result {
            case .success(let status):
                self.state.unfinalizedBolus?.cancel(at: Date())
                self.updateStateFromPodStatus(status: status)
                completion(.success(self.state.unfinalizedBolus?.doseEntry()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func cancelTempBasal(completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        podCommManager.stopProgram(programType: .tempBasal) { (result) in
            switch result {
            case .success(let status):
                self.state.unfinalizedTempBasal?.cancel(at: Date())
                self.updateStateFromPodStatus(status: status)

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func enactTempBasal(unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {

        guard duration > 0 else {
            cancelTempBasal(completion: completion)
            return
        }

        do {
            // Round to nearest supported volume
            let enactRate = roundToSupportedBasalRate(unitsPerHour: unitsPerHour)

            let tempBasal = try TempBasal(value: .flatRate(Int(round(enactRate * 100))), duration: duration)
            let program = ProgramType.tempBasal(tempBasal: tempBasal)

            let startDate = Date()

            let dose = DoseEntry(type: .tempBasal, startDate: startDate, endDate: startDate.addingTimeInterval(duration), value: enactRate, unit: .unitsPerHour)

            podCommManager.sendProgram(programType: program, beepOption: nil) { (result) in
                switch(result) {
                case .success(let podStatus):
                    self.state.unfinalizedTempBasal = UnfinalizedDose(tempBasalRate: enactRate, startTime: startDate, duration: duration, scheduledCertainty: .certain)
                    self.updateStateFromPodStatus(status: podStatus)
                    completion(.success(dose))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } catch let error {
            completion(.failure(error))
        }
    }

    public func setMustProvideBLEHeartbeat(_ mustProvideBLEHeartbeat: Bool) {
        // TODO
    }

    public func suspendDelivery(completion: @escaping (Error?) -> Void) {
        // TODO
    }

    public func resumeDelivery(completion: @escaping (Error?) -> Void) {
        // TODO
    }

    public init(state: DashPumpManagerState, podCommManager: PodCommManagerProtocol = PodCommManager.shared) {
        self.lockedState = Locked(state)
        self.podCommManager = podCommManager
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

    public var debugDescription: String {
        let lines = [
            "## DashPumpManager",
            state.debugDescription,
            "",
        ]

        return lines.joined(separator: "\n")
    }
}
