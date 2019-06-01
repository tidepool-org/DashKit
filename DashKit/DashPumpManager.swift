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
import PodSDK
import os.log


//
public protocol PodStatusObserver: class {
    func didUpdatePodStatus()
}

public class DashPumpManager: PumpManager {

    public static var managerIdentifier = "OmnipodDash"

    let podCommManager: PodCommManager

    public let log = OSLog(category: "DashPumpManager")

    public static let localizedTitle = LocalizedString("Omnipod DASH", comment: "Generic title of the omnipod DASH pump manager")

    public func roundToSupportedBasalRate(unitsPerHour: Double) -> Double {
         return supportedBasalRates.filter({$0 <= unitsPerHour}).max()!
    }

    public func roundToSupportedBolusVolume(units: Double) -> Double {
        return supportedBolusVolumes.filter({$0 <= units}).max()!
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
        print("Notifying bolusState: \(status.bolusState)")
        statusObservers.forEach { (observer) in
            observer.pumpManager(self, didUpdate: status, oldStatus: oldStatus)
        }
    }

    public var basalProgram: BasalProgram {
        return BasalProgram(basalSchedule: state.basalSchedule)
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

    private func updateStateFromPodStatus(status: PodStatus) {
        state.lastStatusDate = Date()
        state.reservoirLevel = ReservoirLevel(rawValue: status.reservoirUnitsRemaining)
        state.podActivatedAt = Date().addingTimeInterval(TimeInterval(-status.timeSinceActivation))
        notifyPodStatusObservers()
    }

    public func getPodStatus(completion: @escaping (PodCommResult<PodStatus>) -> ()) {
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
        return podCommManager.startPodActivation(lowReservoirAlert: lowReservoirAlert, podExpirationAlert: podExpirationAlert) { (activationStatus) in
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

    public func deactivatePod(completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        podCommManager.deactivatePod { (result) in
            completion(result)
        }
    }

    private var isPumpDataStale: Bool {
        let pumpStatusAgeTolerance = TimeInterval(minutes: 6)
        let pumpDataAge = -(state.lastStatusDate ?? .distantPast).timeIntervalSinceNow
        return pumpDataAge > pumpStatusAgeTolerance
    }

    public func assertCurrentPumpData() {
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

            let date = Date()
            let endDate = date.addingTimeInterval(enactUnits / Pod.bolusDeliveryRate)
            let dose = DoseEntry(type: .bolus, startDate: date, endDate: endDate, value: enactUnits, unit: .units)

            willRequest(dose)

            defer { self.state.bolusTransition = nil }
            self.state.bolusTransition = .initiating

            PodCommManager.shared.sendProgram(programType: program, beepOption: nil) { (result) in
                switch(result) {
                case .success( _):
                    self.state.unfinalizedBolus = UnfinalizedDose(bolusAmount: enactUnits, startTime: date, scheduledCertainty: .certain)
                    completion(.success(dose))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } catch let error {
            completion(.failure(error))
        }
    }

    public func cancelBolus(completion: @escaping (PumpManagerResult<DoseEntry?>) -> Void) {
        // TODO
    }

    public func enactTempBasal(unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {

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

    public init(state: DashPumpManagerState) {
        self.lockedState = Locked(state)
        self.podCommManager = PodCommManager.shared
    }

    public required init?(rawState: PumpManager.RawStateValue) {
        guard let state = DashPumpManagerState(rawValue: rawState) else
        {
            return nil
        }

        self.podCommManager = PodCommManager.shared
        self.lockedState = Locked(state)
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
