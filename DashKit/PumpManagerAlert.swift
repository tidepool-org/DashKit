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
import HealthKit

public enum PumpManagerAlert: Hashable {
    case autoOff
    case multiCommand
    case podExpireImminent
    case userPodExpiration(scheduledExpirationReminderOffset: TimeInterval)
    case lowReservoir(lowReservoirReminderValue: Double)
    case suspendInProgress
    case suspendEnded
    case podExpiring
    case timeOffsetChangeDetected
    
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
        
    var contentTitle: String {
        switch self {
        case .autoOff:
            return LocalizedString("Auto Off Alert", comment: "Alert content title for autoOff pod alert")
        case .multiCommand:
            return LocalizedString("Multiple Command Alert", comment: "Alert content title for multiCommand pod alert")
        case .userPodExpiration:
            return LocalizedString("Pod Expiration Reminder", comment: "Alert content title for userPodExpiration pod alert")
        case .podExpiring:
            return LocalizedString("Pod Expired", comment: "Alert content title for podExpiring pod alert")
        case .podExpireImminent:
            return LocalizedString("Pod Expired", comment: "Alert content title for podExpireImminent pod alert")
        case .lowReservoir:
            return LocalizedString("Low Reservoir", comment: "Alert content title for lowReservoir pod alert")
        case .suspendInProgress:
            return LocalizedString("Suspend In Progress Reminder", comment: "Alert content title for suspendInProgress pod alert")
        case .suspendEnded:
            return LocalizedString("Resume Insulin", comment: "Alert content title for suspendEnded pod alert")
        case .timeOffsetChangeDetected:
            return LocalizedString("Time Change Detected", comment: "Alert content title for timeOffsetChangeDetected pod alert")
        }
    }
    
    var contentBody: String {
        switch self {
        case .autoOff:
            return LocalizedString("Auto Off Alert", comment: "Alert content body for autoOff pod alert")
        case .multiCommand:
            return LocalizedString("Multiple Command Alert", comment: "Alert content body for multiCommand pod alert")
        case .userPodExpiration(let offset):
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour]
            formatter.unitsStyle = .full
            let timeString = formatter.string(from: TimeInterval(offset))!
            return String(format: LocalizedString("Pod expires in %1$@.", comment: "Format string for alert content body for userPodExpiration pod alert. (1: time until expiration)"), timeString)
        case .podExpiring:
            return LocalizedString("Change Pod now. Pod has been active for 72 hours.", comment: "Alert content body for podExpiring pod alert")
        case .podExpireImminent:
            return LocalizedString("Change Pod now. Insulin delivery will stop in 1 hour.", comment: "Alert content body for podExpireImminent pod alert")
        case .lowReservoir(let lowReservoirReminderValue):
            let quantityFormatter = QuantityFormatter(for: .internationalUnit())
            let valueString = quantityFormatter.string(from: HKQuantity(unit: .internationalUnit(), doubleValue: lowReservoirReminderValue), for: .internationalUnit()) ?? String(describing: lowReservoirReminderValue)
            return String(format: LocalizedString("%1$@ insulin or less remaining in Pod. Change Pod soon.", comment: "Format string for alert content body for lowReservoir pod alert. (1: reminder value)"), valueString)
        case .suspendInProgress:
            return LocalizedString("Suspend In Progress Reminder", comment: "Alert content body for suspendInProgress pod alert")
        case .suspendEnded:
            return LocalizedString("The insulin suspension period has ended.\n\nYou can resume delivery from the banner on the home screen or from your pump settings screen. You will be reminded again in 15 minutes.", comment: "Alert content body for suspendEnded pod alert")
        case .timeOffsetChangeDetected:
            return LocalizedString("The time on your pump is different from the current time. You can review the pump time and and sync to current time in settings.", comment: "Alert content body for timeOffsetChangeDetected pod alert")
        }
    }
    
    // Override background (UserNotification) content
    
    var backgroundContentTitle: String {
        return contentTitle
    }
    
    var backgroundContentBody: String {
        switch self {
        case .suspendEnded:
            return LocalizedString("Suspension time is up. Open the app and resume.", comment: "Alert notification body for suspendEnded pod alert user notification")
        default:
            return contentBody
        }
    }

    
    var actionButtonLabel: String {
        return LocalizedString("Ok", comment: "Action button default text for PodAlerts")
    }
    
    var foregroundContent: Alert.Content {
        return Alert.Content(title: contentTitle, body: contentBody, acknowledgeActionButtonLabel: actionButtonLabel)
    }
    
    var backgroundContent: Alert.Content {
        return Alert.Content(title: backgroundContentTitle, body: backgroundContentBody, acknowledgeActionButtonLabel: actionButtonLabel)
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
        default:
            return []
        }
    }
    
    var alertIdentifier: String {
        switch self {
        case .autoOff:
            return "autoOff"
        case .multiCommand:
            return "multiCommand"
        case .userPodExpiration:
            return "userPodExpiration"
        case .podExpiring:
            return "podExpiring"
        case .podExpireImminent:
            return "podExpireImminent"
        case .lowReservoir:
            return "lowReservoir"
        case .suspendInProgress:
            return "suspendInProgress"
        case .suspendEnded:
            return "suspendEnded"
        case .timeOffsetChangeDetected:
            return "timeOffsetChangeDetected"
        }
    }
        
    var repeatingAlertIdentifier: String {
        return alertIdentifier + "-repeating"
    }

    var metadata: Alert.Metadata? {
        switch self {
        case .userPodExpiration(let offset):
            return ["offset": Alert.MetadataValue(offset)]
        case .lowReservoir(let lowReservoirReminderValue):
            return ["lowReservoirReminderValue": Alert.MetadataValue(lowReservoirReminderValue)]
        default:
            return nil
        }
    }
}

extension Collection where Element == PumpManagerAlert {
    var podAlerts: PodAlerts {
        var podAlerts = PodAlerts()
        self.forEach { podAlerts.insert($0.podAlerts) }
        return podAlerts
    }
}

extension PumpManagerAlert: RawRepresentable {
    
    public typealias RawValue = [String: Any]
    
    public init?(rawValue: RawValue) {
        guard let identifier = rawValue["identifier"] as? String else {
            return nil
        }
        
        switch identifier {
        case "autoOff":
            self = .autoOff
        case "multiCommand":
            self = .multiCommand
        case "userPodExpiration":
            guard let offset = rawValue["offset"] as? TimeInterval else {
                return nil
            }
            self = .userPodExpiration(scheduledExpirationReminderOffset: offset)
        case "podExpiring":
            self = .podExpiring
        case "podExpireImminent":
            self = .podExpireImminent
        case "lowReservoir":
            guard let value = rawValue["value"] as? Double else {
                return nil
            }
            self = .lowReservoir(lowReservoirReminderValue: value)
        case "suspendInProgress":
            self = .suspendInProgress
        case "suspendEnded":
            self = .suspendEnded
        case "timeOffsetChangeDetected":
            self = .timeOffsetChangeDetected
        default:
            return nil
        }
    }

    public var rawValue: [String : Any] {
        switch self {
        case .lowReservoir(lowReservoirReminderValue: let value):
            return ["identifier": alertIdentifier, "value": value]
        case .userPodExpiration(scheduledExpirationReminderOffset: let offset):
            return ["identifier": alertIdentifier, "offset": offset]
        default:
            return ["identifier:": alertIdentifier]
        }
    }
}

extension PodAlerts {
    
    var isIgnored: Bool {
        switch self {
        case .suspendInProgress:
            return true
        default:
            return false
        }
    }
    
    func asArray() -> [PodAlerts] {
        var alerts: [PodAlerts] = []
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
