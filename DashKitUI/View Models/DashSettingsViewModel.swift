//
//  DashSettingsViewModel.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/8/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import DashKit
import SwiftUI


class DashSettingsViewModel: DashSettingsViewModelProtocol {
    @Published var lifeState: PodLifeState
    
    private let pumpManager: DashPumpManager

    init(pumpManager: DashPumpManager) {
        self.pumpManager = pumpManager
        
        lifeState = pumpManager.lifeState
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
                let timeActive = Date().timeIntervalSince(activationTime)
                if timeActive < Pod.lifetime {
                    return .timeRemaining(Pod.lifetime - timeActive)
                } else {
                    return .expiredSince(timeActive - Pod.lifetime)
                }
            } else {
                return .podDeactivating
            }
        case .systemError(let error):
            return .systemError(error)
        }
    }
}
