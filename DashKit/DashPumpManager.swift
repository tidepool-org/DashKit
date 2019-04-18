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

    public var pumpManagerDelegate: PumpManagerDelegate?

    public var pumpRecordsBasalProfileStartEvents = false

    public var pumpReservoirCapacity: Double {
        return Pod.reservoirCapacity
    }

    public private(set) var state: DashPumpManagerState {
        didSet {
            pumpManagerDelegate?.pumpManagerDidUpdateState(self)
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
            localIdentifier: "podid",
            udiDeviceIdentifier: nil
        )
    }

    public var status: PumpManagerStatus {
        return PumpManagerStatus.init(timeZone: state.timeZone, device: device, pumpBatteryChargeRemaining: nil, basalDeliveryState: .active, bolusState: .none)
    }

    private var statusObservers = WeakSet<PumpManagerStatusObserver>()

    public func addStatusObserver(_ observer: PumpManagerStatusObserver) {
        self.statusObservers.insert(observer)
    }

    public func removeStatusObserver(_ observer: PumpManagerStatusObserver) {
        self.statusObservers.remove(observer)
    }

    public func assertCurrentPumpData() {
        // TODO
    }

    public func createBolusProgressReporter(reportingOn dispatchQueue: DispatchQueue) -> DoseProgressReporter? {
        // TODO
        return nil
    }

    public func enactBolus(units: Double, at startDate: Date, willRequest: @escaping (DoseEntry) -> Void, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        // TODO
    }

    public func cancelBolus(completion: @escaping (PumpManagerResult<DoseEntry?>) -> Void) {
        // TODO
    }

    public func enactTempBasal(unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        // TODO
    }

    public func updateBLEHeartbeatPreference() {
        // TODO
    }

    public func suspendDelivery(completion: @escaping (Error?) -> Void) {
        // TODO
    }

    public func resumeDelivery(completion: @escaping (Error?) -> Void) {
        // TODO
    }

    public required init?(rawState: PumpManager.RawStateValue) {

        guard let state = DashPumpManagerState(rawValue: rawState) else
        {
            return nil
        }

        self.state = state
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
