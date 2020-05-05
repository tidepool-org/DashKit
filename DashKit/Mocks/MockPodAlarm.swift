//
//  MockPodAlarm.swift
//  DashKit
//
//  Created by Pete Schwamb on 3/31/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import PodSDK

public struct MockPodAlarm: PodAlarm {
    public var alarmCode: AlarmCode
    
    public var alarmDescription: String
    
    public var podStatus: PodStatus
    
    public var occlusionType: OcclusionType
    
    public var didErrorOccuredFetchingBolusInfo: Bool
    
    public var wasBolusActiveWhenPodAlarmed: Bool
    
    public var podStateWhenPodAlarmed: PodState
    
    public var podStateWhenAlarmOccurred: PodState
    
    public var alarmTime: Date?
    
    public var activationTime: Date
    
    public var referenceCode: String
    
    public init(
        alarmCode: AlarmCode = .podExpired,
        alarmDescription: String = "Pod Expired",
        podStatus: PodStatus = MockPodStatus.normal,
        occlusionType: OcclusionType = .none,
        didErrorOccuredFetchingBolusInfo: Bool = false,
        wasBolusActiveWhenPodAlarmed: Bool = false,
        podStateWhenPodAlarmed: PodState = .basalProgramRunning,
        podStateWhenAlarmOccurred: PodState = .basalProgramRunning,
        alarmTime: Date? = Date(),
        activationTime: Date = Date() - 10 * 60 * 60,
        referenceCode: String = "123"
    ) {
        self.alarmCode = alarmCode
        self.alarmDescription = alarmDescription
        self.podStatus = podStatus
        self.occlusionType = occlusionType
        self.didErrorOccuredFetchingBolusInfo = didErrorOccuredFetchingBolusInfo
        self.wasBolusActiveWhenPodAlarmed = wasBolusActiveWhenPodAlarmed
        self.podStateWhenPodAlarmed = podStateWhenPodAlarmed
        self.podStateWhenAlarmOccurred = podStateWhenAlarmOccurred
        self.alarmTime = alarmTime
        self.activationTime = activationTime
        self.referenceCode = referenceCode
    }
    
    public static var occlusion: MockPodAlarm {
        return MockPodAlarm(
            alarmCode: .occlusion,
            alarmDescription: "Occlusion",
            podStatus: MockPodStatus.normal,
            occlusionType: .stallDuringRuntime,
            didErrorOccuredFetchingBolusInfo: false,
            wasBolusActiveWhenPodAlarmed: false,
            podStateWhenPodAlarmed: .runningAboveMinVolume,
            podStateWhenAlarmOccurred: .runningAboveMinVolume,
            alarmTime: Date().addingTimeInterval(.minutes(10)),
            activationTime: Date().addingTimeInterval(.hours(24)),
            referenceCode: "123")
    }

}
