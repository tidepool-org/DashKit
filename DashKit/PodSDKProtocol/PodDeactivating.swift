//
//  PodDeactivating.swift
//  DashKit
//
//  Created by Pete Schwamb on 3/10/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import PodSDK

public protocol PodDeactivating {
    func deactivatePod(completion: @escaping (PodCommResult<PodStatus>) -> ())
    func discardPod(completion: @escaping (PodCommResult<Bool>) -> ())
}

extension DashPumpManager: PodDeactivating { }
