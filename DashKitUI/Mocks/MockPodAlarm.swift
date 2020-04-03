//
//  MockPodAlarm.swift
//  DashKitUI
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
    
    var referenceCode: String = "MockReferenceCode"
}
