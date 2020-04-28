//
//  MockPodAlarm.swift
//  DashKit
//
//  Created by Pete Schwamb on 3/31/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import PodSDK

struct MockPodAlarm: PodAlarm {
    var alarmCode: AlarmCode = .podExpired
    
    var alarmDescription: String = "Pod Expired"
    
    var podStatus: PodStatus = MockPodStatus.normal
    
    var occlusionType: OcclusionType = .none
    
    var didErrorOccuredFetchingBolusInfo: Bool = false
    
    var wasBolusActiveWhenPodAlarmed: Bool = false
    
    var podStateWhenPodAlarmed: PodState = .basalProgramRunning
    
    var podStateWhenAlarmOccurred: PodState = .basalProgramRunning
    
    var alarmTime: Date? = Date()
    
    var activationTime: Date = Date() - 10 * 60 * 60
    
    var referenceCode: String = "123"
    
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
