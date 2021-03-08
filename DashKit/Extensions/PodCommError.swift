//
//  PodCommError.swift
//  DashKit
//
//  Created by Pete Schwamb on 3/2/21.
//  Copyright © 2021 Tidepool. All rights reserved.
//

import SwiftUI
import PodSDK

public extension PodCommError {
    var recoverable: Bool {
        switch self {
        case .podIsInAlarm:
            return false
        case .activationError(let activationErrorCode):
            switch activationErrorCode {
            case .podIsLumpOfCoal1Hour, .podIsLumpOfCoal2Hours:
                return false
            default:
                return true
            }
        case .internalError(.incompatibleProductId):
            return false
        case .systemError:
            return false
        default:
            return true
        }
    }
}
