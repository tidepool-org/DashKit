//
//  PodAlerts.swift
//  DashKit
//
//  Created by Pete Schwamb on 7/20/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import PodSDK

extension PodAlerts: CustomDebugStringConvertible {
    public var debugDescription: String {
        let allAlerts: [PodAlerts] = [.autoOff, .lowReservoir, .multiCommand, .podExpireImminent, .podExpiring, .suspendEnded, .suspendInProgress, .userPodExpiration]
        var alertDescriptions: [String] = []
        for alert in allAlerts {
            if self.contains(alert) {
                var alertDescription = { () -> String in
                    switch alert {
                    case .autoOff:
                        return "Auto-Off"
                    case .lowReservoir:
                        return "Low Reservoir"
                    case .multiCommand:
                        return "Multi-Command"
                    case .podExpireImminent:
                        return "Pod Expire Imminent"
                    case .podExpiring:
                        return "Pod Expiring"
                    case .suspendEnded:
                        return "Suspend Ended"
                    case .suspendInProgress:
                        return "Suspend In Progress"
                    case .userPodExpiration:
                        return "User Pod Expiration"
                    default:
                        fatalError()
                    }
                }()
                if let alertTime = getAlertsTime(podAlert: alert) {
                    alertDescription += ": \(alertTime)"
                }
                alertDescriptions.append(alertDescription)
            }
        }
        return "PodAlerts(\(alertDescriptions.joined(separator: ", ")))"
    }
}
