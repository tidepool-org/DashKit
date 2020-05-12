//
//  PodDeactivater.swift
//  DashKit
//
//  Created by Pete Schwamb on 3/10/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import PodSDK

public protocol PodDeactivater {
    func deactivatePod(completion: @escaping (PodCommResult<PartialPodStatus>) -> ())
    func discardPod(completion: @escaping (PodCommResult<Bool>) -> ())
}

extension DashPumpManager: PodDeactivater { }
