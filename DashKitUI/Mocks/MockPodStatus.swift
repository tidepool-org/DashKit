//
//  MockPodStatus.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/9/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import PodSDK

struct MockPodStatus: PodStatus {
    var expirationDate: Date

    var podState: PodState

    var programStatus: ProgramStatus

    var activeAlerts: PodAlerts

    var isOcclusionAlertActive: Bool

    var bolusUnitsRemaining: Int

    var totalUnitsDelivered: Int

    var reservoirUnitsRemaining: Int

    var timeElapsedSinceActivation: TimeInterval

    var activationTime: Date

    func hasAlerts() -> Bool {
        return !activeAlerts.isEmpty
    }
    
    static var normal: MockPodStatus {
        let activation = Date().addingTimeInterval(.hours(-2))
        return MockPodStatus(
            expirationDate: activation + TimeInterval(days: 3),
            podState: .runningAboveMinVolume,
            programStatus: .basalRunning,
            activeAlerts: PodAlerts([]),
            isOcclusionAlertActive: false,
            bolusUnitsRemaining: 0,
            totalUnitsDelivered: 38,
            reservoirUnitsRemaining: 1023,
            timeElapsedSinceActivation: 2,
            activationTime: activation)
    }
}
