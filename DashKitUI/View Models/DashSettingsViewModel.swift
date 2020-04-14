//
//  DashSettingsViewModel.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/8/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import DashKit
import SwiftUI
import LoopKit

class DashSettingsViewModel: DashSettingsViewModelProtocol {
    @Published var lifeState: PodLifeState

    var podDetails: PodDetails {
        return self.pumpManager
    }

    private let pumpManager: DashPumpManager
    
    
    init(pumpManager: DashPumpManager) {
        self.pumpManager = pumpManager
        
        lifeState = pumpManager.lifeState
        pumpManager.addStatusObserver(self, queue: DispatchQueue.main)
    }

    func suspendResumeTapped() {
        guard let deliveryState = lifeState.deliveryState else {
            return
        }
        
        switch deliveryState {
        case .active:
            pumpManager.suspendDelivery { (error) in
                if let error = error {
                    // TODO: Display error
                }
            }
        case .suspended:
            pumpManager.resumeDelivery { (error) in
                if let error = error {
                    // TODO: Display error
                }
            }
        default:
            break
        }
    }
}

extension DashSettingsViewModel: PumpManagerStatusObserver {
    func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus) {
        self.lifeState = self.pumpManager.lifeState
    }
    
    
}

extension PumpManagerStatus.BasalDeliveryState {
    var podDeliveryState: PodDeliveryState {
        switch self {
        case .active, .initiatingTempBasal, .tempBasal, .cancelingTempBasal:
            return .active
        case .resuming:
            return .resuming
        case .suspending:
            return .suspending
        case .suspended:
            return .suspended
        }
    }
}

extension DashPumpManager {
    var lifeState: PodLifeState {
        switch podCommState {
        case .alarm(let alarm):
            return .podAlarm(alarm)
        case .noPod:
            return .noPod
        case .activating:
            return .podActivating
        case .deactivating:
            return .podDeactivating
        case .active:
            if let activationTime = podActivatedAt {
                let podDeliveryState = status.basalDeliveryState.podDeliveryState
                
                let timeActive = Date().timeIntervalSince(activationTime)
                if timeActive < Pod.lifetime {
                    return .timeRemaining(Pod.lifetime - timeActive, podDeliveryState, activationTime)
                } else {
                    return .expiredSince(timeActive - Pod.lifetime, podDeliveryState, activationTime)
                }
            } else {
                return .podDeactivating
            }
        case .systemError(let error):
            return .systemError(error)
        }
    }
}

extension DashPumpManager: PodDetails {
    var podIdentifier: String {
        return podId ?? "None"
    }
    
    var lot: String {
        return "TODO"
    }
    
    var tid: String {
        return "TODO"
    }
    
    var piPmVersion: String {
        return "TODO"
    }
    
    var pdmIdentifier: String {
        return "TODO"
    }
    
}
