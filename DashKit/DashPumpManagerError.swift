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
    
    /// A localized message describing what error occurred.
    public var errorDescription: String? {
        switch self {
        case .missingSettings:
            return LocalizedString("Missing Settings.", comment: "Description of registration error when already registered.")
        case .invalidBasalSchedule:
            return LocalizedString("Invalid Basal Schedule.", comment: "Description of registration error for connection timeout.")
        case .podCommError:
            return LocalizedString("There was a problem communicating with the pod.", comment: "Description of communication error with pod.")
        case .busy:
            return LocalizedString("Pod Busy.", comment: "Description of registration error when error is unknown.")
        }
    }

}

extension DashPumpManagerError {
    init(_ podCommError: PodCommError) {
        self = .podCommError(description: String(describing: podCommError))
    }
}

