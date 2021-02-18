//
//  PodPairer.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/5/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation

import PodSDK

public protocol PodPairer {
    func pair(eventListener: @escaping (ActivationStatus<ActivationStep1Event>) -> ())
    func discardPod(completion: @escaping (PodCommResult<Bool>) -> ())

    var podCommState: PodCommState { get }
}

extension DashPumpManager: PodPairer {
    public func pair(eventListener: @escaping (ActivationStatus<ActivationStep1Event>) -> ()) {
        guard let podExpirationAlert = try? PodExpirationAlert(intervalBeforeExpiration: state.defaultExpirationReminderOffset) else {
            eventListener(.error(.invalidAlertSetting))
            return
        }
        
        guard let lowReservoirAlert = try? LowReservoirAlert(reservoirVolumeBelow: Int(Double(state.lowReservoirReminderValue) * Pod.podSDKInsulinMultiplier)) else {
            eventListener(.error(.invalidAlertSetting))
            return
        }
        
        startPodActivation(
            lowReservoirAlert: lowReservoirAlert,
            podExpirationAlert: podExpirationAlert,
            eventListener: eventListener)
    }
}
