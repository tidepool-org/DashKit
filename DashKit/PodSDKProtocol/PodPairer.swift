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
        startPodActivation(
            lowReservoirAlert: try! LowReservoirAlert(reservoirVolumeBelow: 1000), // TODO: Configurable
            podExpirationAlert: try! PodExpirationAlert(intervalBeforeExpiration: 4 * 60 * 60), // TODO: Configurable
            eventListener: eventListener)
    }
}
