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
    case invalidBolusVolume
    case invalidTempBasalRate
    case podCommError(PodCommError)
    case busy
    
    /// A localized message describing what error occurred.
    public var errorDescription: String? {
        switch self {
        case .missingSettings:
            return LocalizedString("Missing settings.", comment: "Description of DashPumpManagerError for .missingSettings.")
        case .invalidBasalSchedule:
            return LocalizedString("Invalid basal schedule.", comment: "Description of DashPumpManagerError for .invalidBasalSchedule")
        case .invalidBolusVolume:
            return LocalizedString("Invalid bolus volume.", comment: "Description of DashPumpManagerError for .invalidBolusVolume")
        case .invalidTempBasalRate:
            return LocalizedString("Invalid temp basal rate.", comment: "Description of DashPumpManagerError for .invalidTempBasalRate")
        case .podCommError(let error):
            return error.errorDescription
        case .busy:
            return LocalizedString("Pod Busy.", comment: "Description of DashPumpManagerError error when pump manager is busy.")
        }
    }
}

extension DashPumpManagerError {
    init(_ podCommError: PodCommError) {
        self = .podCommError(podCommError)
    }
}

