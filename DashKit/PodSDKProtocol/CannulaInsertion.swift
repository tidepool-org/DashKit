//
//  CannulaInsertion.swift
//  DashKit
//
//  Created by Pete Schwamb on 3/10/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import PodSDK

public protocol CannulaInsertion {
    func insertCannula(eventListener: @escaping (ActivationStatus<ActivationStep2Event>) -> ())
}

extension DashPumpManager: CannulaInsertion {
    public func insertCannula(eventListener: @escaping (ActivationStatus<ActivationStep2Event>) -> ()) {
        let autoOffAlert = try! AutoOffAlert(enable: false)
        finishPodActivation(autoOffAlert: autoOffAlert, eventListener: eventListener)
    }
}
