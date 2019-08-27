//
//  DashPumpManagerError.swift
//  DashKit
//
//  Created by Pete Schwamb on 8/26/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import PodSDK

public enum DashPumpManagerError: Error, LocalizedError {
    case missingSettings
    case invalidBasalSchedule
    case podCommError(description: String)
    case busy
}

extension DashPumpManagerError {
    init(_ podCommError: PodCommError) {
        self = .podCommError(description: String(describing: podCommError))
    }
}

