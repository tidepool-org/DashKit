//
//  PodAlert.swift
//  DashKit
//
//  Created by Pete Schwamb on 7/9/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import PodSDK
import LoopKit

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
    
    var isRepeating: Bool {
        return repeatInterval != nil
    }
    
    var repeatInterval: TimeInterval? {
        switch self {
        case .suspendEnded:
            return .minutes(15)
        default:
            return nil
        }
    }
    
    var alertIdentifier: String {
        return rawValue
    }
    
    var repeatingAlertIdentifier: String {
        return rawValue + "-repeating"
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
            return LocalizedString("Low Reservoir", comment: "Alert content title for lowReservoir pod alert")
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
            return LocalizedString("Auto Off Alert", comment: "Alert content body for autoOff pod alert")
        case .multiCommand:
            return LocalizedString("Multiple Command Alert", comment: "Alert content body for multiCommand pod alert")
        case .podExpireImminent:
            return LocalizedString("Pod Expiration Imminent", comment: "Alert content body for podExpireImminent pod alert")
        case .userPodExpiration:
            return LocalizedString("Pod Expiration Reminder", comment: "Alert content body for userPodExpiration pod alert")
        case .lowReservoir:
            return LocalizedString("10 U insulin or less remaining in Pod.\nChange Pod soon", comment: "Alert content body for lowReservoir pod alert")
        case .suspendInProgress:
            return LocalizedString("Suspend In Progress Reminder", comment: "Alert content body for suspendInProgress pod alert")
        case .suspendEnded:
            return LocalizedString("The insulin suspension period has ended.\n\nYou can resume delivery from the banner on the home screen or from your pump settings screen. You will be reminded again in 15 minutes.", comment: "Alert content body for suspendEnded pod alert")
        case .podExpiring:
            return LocalizedString("Pod Expiring", comment: "Alert content body for podExpiring pod alert")
        }
    }
    
    var backgroundContentBody: String {
        switch self {
        case .suspendEnded:
            return LocalizedString("Suspension time is up. Open the app and resume.", comment: "Alert notification body for suspendEnded pod alert")
        default:
            return contentBody
        }
    }

    
    var actionButtonLabel: String {
        switch self {
        case .suspendEnded:
            return LocalizedString("OK", comment: "Action button text to acknowledge pump resume")
        default:
            return LocalizedString("Acknowledge", comment: "Action button default text for PodAlerts")
        }
    }
    
    var foregroundContent: Alert.Content {
        return Alert.Content(title: contentTitle, body: contentBody, acknowledgeActionButtonLabel: actionButtonLabel)
    }
    
    var backgroundContent: Alert.Content {
        return Alert.Content(title: contentTitle, body: backgroundContentBody, acknowledgeActionButtonLabel: actionButtonLabel)
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
