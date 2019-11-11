//
//  AlarmCode.swift
//  DashKit
//
//  Created by Pete Schwamb on 11/5/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import PodSDK

extension AlarmCode {
    var notificationTitle: String {
        switch self {
        case .autoOff:
            return NSLocalizedString("Auto Off Alarm", comment: "The title for Auto-Off alarm notification")
        case .emptyReservoir:
            return NSLocalizedString("Empty Reservoir Alarm", comment: "The title for Empty Reservoir alarm notification")
        case .occlusion:
            return NSLocalizedString("Occlusion Detected", comment: "The title for Occlusion alarm notification")
        case .other:
            return NSLocalizedString("Call Customer Care", comment: "The title for AlarmCode.other notification")
        case .podExpired:
            return NSLocalizedString("Pod Expired", comment: "The title for Pod Expired alarm notification")
        }
    }
    
    var notificationBody: String {
        switch self {
        case .other:
            return NSLocalizedString("Remove Pod Now. Call Customer Care at 1 800-591-3455", comment: "The body of AlarmCode.other notification")
        default:
            return NSLocalizedString("Insulin delivery stopped. Deactivate Pod now,", comment: "The notification body for known AlarmCodes")
        }
    }
}
