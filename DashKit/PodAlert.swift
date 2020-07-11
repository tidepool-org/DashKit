//
//  PodAlert.swift
//  DashKit
//
//  Created by Pete Schwamb on 7/9/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import PodSDK

public enum PodAlert: String {
    case autoOff
    case multiCommand
    case podExpireImminent
    case userPodExpiration
    case lowReservoir
    case suspendInProgress
    case suspendEnded
    case podExpiring
    
    var isIgnored: Bool {
        switch self {
        case .suspendInProgress:
            return true
        default:
            return false
        }
    }
    
    var alertIdentifier: String {
        return rawValue
    }
    
    var contentTitle: String {
        switch self {
        case .autoOff:
            return LocalizedString("Auto Off Alert", comment: "Alert content title for autoOff pod alert")
        case .multiCommand:
            return LocalizedString("Multiple Command Alert", comment: "Alert content title for multiCommand pod alert")
        case .podExpireImminent:
            return LocalizedString("Pod Expiration Imminent", comment: "Alert content title for podExpireImminent pod alert")
        case .userPodExpiration:
            return LocalizedString("Pod Expiration Reminder", comment: "Alert content title for userPodExpiration pod alert")
        case .lowReservoir:
            return LocalizedString("Low Reservoir Alert", comment: "Alert content title for lowReservoir pod alert")
        case .suspendInProgress:
            return LocalizedString("Suspend In Progress Reminder", comment: "Alert content title for suspendInProgress pod alert")
        case .suspendEnded:
            return LocalizedString("Resume Insulin", comment: "Alert content title for suspendEnded pod alert")
        case .podExpiring:
            return LocalizedString("Pod Expiring", comment: "Alert content title for podExpiring pod alert")
        }
    }
    
    var contentBody: String {
        switch self {
        case .autoOff:
            return LocalizedString("Auto Off Alert", comment: "Alert content title for autoOff pod alert")
        case .multiCommand:
            return LocalizedString("Multiple Command Alert", comment: "Alert content title for multiCommand pod alert")
        case .podExpireImminent:
            return LocalizedString("Pod Expiration Imminent", comment: "Alert content title for podExpireImminent pod alert")
        case .userPodExpiration:
            return LocalizedString("Pod Expiration Reminder", comment: "Alert content title for userPodExpiration pod alert")
        case .lowReservoir:
            return LocalizedString("Low Reservoir Alert", comment: "Alert content title for lowReservoir pod alert")
        case .suspendInProgress:
            return LocalizedString("Suspend In Progress Reminder", comment: "Alert content title for suspendInProgress pod alert")
        case .suspendEnded:
            return LocalizedString("The insulin suspension period has ended. Please resume insulin from the pod settings screen.", comment: "Alert content title for suspendEnded pod alert")
        case .podExpiring:
            return LocalizedString("Pod Expiring", comment: "Alert content title for podExpiring pod alert")
        }
    }
    
    var actionButtonLabel: String {
        switch self {
        case .suspendEnded:
            return LocalizedString("Remind me in 15 minutes", comment: "Action button text for suspendEnded PodAlert")
        default:
            return LocalizedString("Acknowledge", comment: "Action button default text for PodAlerts")
        }
    }
    
    var podAlerts: PodAlerts {
        switch self {
        case .autoOff:
            return PodAlerts.autoOff
        case .multiCommand:
            return PodAlerts.multiCommand
        case .podExpireImminent:
            return PodAlerts.podExpireImminent
        case .userPodExpiration:
            return PodAlerts.userPodExpiration
        case .lowReservoir:
            return PodAlerts.lowReservoir
        case .suspendInProgress:
            return PodAlerts.suspendInProgress
        case .suspendEnded:
            return PodAlerts.suspendEnded
        case .podExpiring:
            return PodAlerts.podExpiring
        }
    }
}

extension PodAlerts {
    var allPodAlerts: [PodAlert] {
        var alerts: [PodAlert] = []
        if self.contains(.autoOff) {
            alerts.append(.autoOff)
        }
        if self.contains(.multiCommand) {
            alerts.append(.multiCommand)
        }
        if self.contains(.podExpireImminent) {
            alerts.append(.podExpireImminent)
        }
        if self.contains(.userPodExpiration) {
            alerts.append(.userPodExpiration)
        }
        if self.contains(.lowReservoir) {
            alerts.append(.lowReservoir)
        }
        if self.contains(.suspendInProgress) {
            alerts.append(.suspendInProgress)
        }
        if self.contains(.suspendEnded) {
            alerts.append(.suspendEnded)
        }
        if self.contains(.podExpiring) {
            alerts.append(.podExpiring)
        }
        return alerts
    }
}
