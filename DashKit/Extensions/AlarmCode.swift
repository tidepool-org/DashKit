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
    public var notificationTitle: String {
        switch self {
        case .autoOff:
            return LocalizedString("Auto Off Alarm", comment: "The title for Auto-Off alarm notification")
        case .emptyReservoir:
            return LocalizedString("Empty Reservoir", comment: "The title for Empty Reservoir alarm notification")
        case .occlusion:
            return LocalizedString("Occlusion Detected", comment: "The title for Occlusion alarm notification")
        case .other:
            return LocalizedString("Pod Error", comment: "The title for AlarmCode.other notification")
        case .podExpired:
            return LocalizedString("Pod Expired", comment: "The title for Pod Expired alarm notification")
        }
    }
    
    public var notificationBody: String {
        return LocalizedString("Insulin delivery stopped. Change Pod now.", comment: "The default notification body for AlarmCodes")
    }
}
