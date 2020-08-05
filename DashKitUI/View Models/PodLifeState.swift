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

enum PodLifeState {
    case podActivating
    // Time remaining
    case timeRemaining(TimeInterval)
    // Time since expiry
    case expiredFor(TimeInterval)
    case podDeactivating
    case podAlarm(PodAlarm?)
    case systemError(SystemError)
    case noPod
    
    var progress: Double {
        switch self {
        case .timeRemaining(let timeRemaining):
            return max(0, min(1, timeRemaining / Pod.lifetime))
        case .expiredFor(let expiryAge):
            return max(0, min(1, expiryAge / Pod.expirationWindow))
        case .podAlarm, .systemError, .podDeactivating:
            return 1
        case .noPod, .podActivating:
            return 0
        }
    }
    
    var progressColor: Color {
        if case .timeRemaining = self {
            return progress < 0.25 ? Color(.agingColor) : .accentColor
        }
        return Color(.alarmColor)
    }
    
    var labelColor: Color {
        if case .podAlarm = self {
            return Color(.alarmColor)
        }
        return Color(.secondaryLabel)
    }

    
    var localizedLabelText: String {
        switch self {
        case .podActivating:
            return LocalizedString("Unfinished Activation", comment: "Label for pod life state when pod not fully activated")
        case .timeRemaining:
            return LocalizedString("Pod expires in", comment: "Label for pod life state when time remaining")
        case .expiredFor:
            return LocalizedString("Pod expired", comment: "Label for pod life state when within pod expiration window")
        case .podDeactivating:
            return LocalizedString("Unfinished deactivation", comment: "Label for pod life state when pod not fully deactivated")
        case .podAlarm(let alarm):
            if let alarm = alarm {
                return alarm.alarmDescription
            } else {
                return LocalizedString("Pod alarm", comment: "Label for pod life state when pod is in alarm state")
            }
        case .systemError:
            return LocalizedString("Pod system error", comment: "Label for pod life state when pod is in system error state")
        case .noPod:
            return LocalizedString("No Pod", comment: "Label for pod life state when no pod paired")
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
            return .red
        }
    }

    var isActive: Bool {
        switch self {
        case .expiredFor, .timeRemaining:
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
