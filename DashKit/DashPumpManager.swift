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

// This is for internal observers, like the HUD, so they can have full access to state updates
public protocol DashPumpManagerStateObserver: class {
    func didUpdatePumpManagerState(_ state: DashPumpManagerState)
}

public class DashPumpManager: PumpManager {

    public static var managerIdentifier = "OmnipodDash"

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
        return state.hasActivePod
    }

    public let stateObservers = WeakSynchronizedSet<DashPumpManagerStateObserver>()

    private(set) public var state: DashPumpManagerState {
        get {
            return lockedState.value
        }
        set {
            let oldValue = lockedState.value
            let oldStatus = status
            lockedState.value = newValue

            // PumpManagerStatus may have changed
            if oldValue.timeZone != newValue.timeZone
            {
                notifyStatusObservers(oldStatus: oldStatus)
            }

            if oldValue != newValue {
                pumpDelegate.notify { (delegate) in
                    delegate?.pumpManagerDidUpdateState(self)
                }
                stateObservers.forEach { (observer) in
                    observer.didUpdatePumpManagerState(newValue)
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
            localIdentifier: "podid",
            udiDeviceIdentifier: nil
        )
    }

    public var status: PumpManagerStatus {
        return PumpManagerStatus.init(timeZone: state.timeZone, device: device, pumpBatteryChargeRemaining: nil, basalDeliveryState: .active, bolusState: .none)
    }

    private var statusObservers = WeakSynchronizedSet<PumpManagerStatusObserver>()

    public func addStatusObserver(_ observer: PumpManagerStatusObserver, queue: DispatchQueue) {
        self.statusObservers.insert(observer, queue: queue)
    }

    public func removeStatusObserver(_ observer: PumpManagerStatusObserver) {
        self.statusObservers.removeElement(observer)
    }

    public func assertCurrentPumpData() {
        // TODO
    }

    public func createBolusProgressReporter(reportingOn dispatchQueue: DispatchQueue) -> DoseProgressReporter? {
        // TODO
        return nil
    }

    public func enactBolus(units: Double, at startDate: Date, willRequest: @escaping (DoseEntry) -> Void, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        do {
            let program = ProgramType.bolus(bolus: try Bolus(immediateVolume: Int(round(units * 100))))

            // Round to nearest supported volume
            let enactUnits = roundToSupportedBolusVolume(units: units)

            let date = Date()
            let endDate = date.addingTimeInterval(enactUnits / Pod.bolusDeliveryRate)
            let dose = DoseEntry(type: .bolus, startDate: date, endDate: endDate, value: enactUnits, unit: .units)

            willRequest(dose)

            PodCommManager.shared.sendProgram(programType: program, beepOption: nil) { (result) in
                switch(result) {
                case .success( _):
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
        // TODO
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
    }

    public required init?(rawState: PumpManager.RawStateValue) {
        guard let state = DashPumpManagerState(rawValue: rawState) else
        {
            return nil
        }

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
