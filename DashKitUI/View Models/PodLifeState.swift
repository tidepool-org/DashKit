//
//  PodLifeState.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/9/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation

import PodSDK
import DashKit
import SwiftUI

enum PodDeliveryState {
    case active
    case suspending
    case suspended
    case resuming

    var suspendResumeActionText: String {
        switch self {
        case .active:
            return LocalizedString("Suspend Insulin Delivery", comment: "Text for suspend resume button when insulin delivery active")
        case .suspending:
            return LocalizedString("Suspending Delivery", comment: "Text for suspend resume button when insulin delivery is suspending")
        case .suspended:
            return LocalizedString("Resume Insulin Delivery", comment: "Text for suspend resume button when insulin delivery is suspended")
        case .resuming:
            return LocalizedString("Resuming Insulin Delivery", comment: "Text for suspend resume button when insulin delivery is resuming")
        }
    }
    
    var transitioning: Bool {
        switch self {
        case .suspending, .resuming:
            return true
        default:
            return false
        }
    }
    
    var suspendResumeActionColor: Color {
        switch self {
        case .suspending, .resuming:
            return Color.secondary
        default:
            return Color.accentColor
        }
    }

}

enum PodLifeState {
    case podActivating
    case timeRemaining(TimeInterval, PodDeliveryState, Date)
    case expiredSince(TimeInterval, PodDeliveryState, Date)
    case podDeactivating
    case podAlarm(PodAlarm?)
    case systemError(SystemError?)
    case noPod
    
    var progress: Double {
        switch self {
        case .timeRemaining(let timeRemaining, _, _):
            return max(0, min(1, timeRemaining / Pod.lifetime))
        case .expiredSince(let expiryAge, _, _):
            return max(0, min(1, (Pod.expirationWindow - expiryAge) / Pod.expirationWindow))
        case .podAlarm, .systemError, .podDeactivating:
            return 1
        case .noPod, .podActivating:
            return 0
        }
    }
    
    var localizedLabelText: String {
        switch self {
        case .podActivating:
            return LocalizedString("Unfinished Activation", comment: "Label for pod life state when pod not fully activated")
        case .timeRemaining:
            return LocalizedString("Pod expires in", comment: "Label for pod life state when time remaining")
        case .expiredSince:
            return LocalizedString("Pod expired", comment: "Label for pod life state when within pod expiration window")
        case .podDeactivating:
            return LocalizedString("Unfinished deactivation", comment: "Label for pod life state when pod not fully deactivated")
        case .podAlarm(let alarm):
            if let alarm = alarm {
                return alarm.alarmDescription
            } else {
                return LocalizedString("Pod alarm", comment: "Label for pod life state when pod is in alarm state")
            }
        case .systemError(let error):
            if let error = error {
                // TODO: Localize system errors
                return String(describing: error)
            } else {
                return LocalizedString("Pod system error", comment: "Label for pod life state when pod is in system error state")
            }
        case .noPod:
            return LocalizedString("No Pod", comment: "Label for pod life state when no pod paired")
        }
    }

    var deliveryState: PodDeliveryState? {
        switch self {
        case .expiredSince(_, let deliveryState, _):
            return deliveryState
        case .timeRemaining(_, let deliveryState, _):
            return deliveryState
        default:
            return nil
        }
    }
    
    var activatedAt: Date? {
        switch self {
        case .expiredSince(_, _, let activatedAt):
            return activatedAt
        case .timeRemaining(_, _, let activatedAt):
            return activatedAt
        default:
            return nil
        }
    }


    var nextPodLifecycleAction: DashUIScreen {
        switch self {
        case .podActivating, .noPod:
            return .pairPod
        default:
            return .deactivate
        }
    }
    
    var nextPodLifecycleActionDescription: String {
        switch self {
        case .podActivating, .noPod:
            return LocalizedString("Pair New Pod", comment: "Settings page link description when next lifecycle action is to pair new pod")
        case .podDeactivating:
            return LocalizedString("Finish deactivation", comment: "Settings page link description when next lifecycle action is to finish deactivation")
        default:
            return LocalizedString("Replace Pod", comment: "Settings page link description when next lifecycle action is to replace pod")
        }
    }
    
    var nextPodLifecycleActionColor: Color {
        switch self {
        case .podActivating, .noPod:
            return .accentColor
        default:
            return .destructive
        }
    }

    var isActive: Bool {
        switch self {
        case .expiredSince, .timeRemaining:
            return true
        default:
            return false
        }
    }

    var allowsPumpManagerRemoval: Bool {
        if case .noPod = self {
            return true
        }
        return false
    }
}
