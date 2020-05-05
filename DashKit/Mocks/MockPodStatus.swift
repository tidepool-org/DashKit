//
//  MockPodStatus.swift
//  DashKit
//
//  Created by Pete Schwamb on 3/9/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import PodSDK

public struct MockPodStatus: PodStatus {
    public var expirationDate: Date

    public var podState: PodState

    public var programStatus: ProgramStatus

    public var activeAlerts: PodAlerts

    public var isOcclusionAlertActive: Bool

    public var bolusUnitsRemaining: Int

    public var totalUnitsDelivered: Int

    public var reservoirUnitsRemaining: Int

    public var timeElapsedSinceActivation: TimeInterval

    public var activationTime: Date

    public func hasAlerts() -> Bool {
        return !activeAlerts.isEmpty
    }
    
    public static var normal: MockPodStatus {
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
