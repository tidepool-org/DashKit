//
//  SettingsViewModelProtocol.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/8/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import LoopKit
import PodSDK

struct BasalDeliveryRate {
    var absoluteRate: Double
    var netPercent: Double
}

protocol DashSettingsViewModelProtocol: ObservableObject, Identifiable {
    var lifeState: PodLifeState { get }

    var activatedAt: Date? { get }
    
    var basalDeliveryState: PumpManagerStatus.BasalDeliveryState { get }
    
    var basalDeliveryRate: BasalDeliveryRate? { get }

    var podDetails: PodDetails { get }
    
    var dateFormatter: DateFormatter { get }
    
    var basalRateFormatter: NumberFormatter { get }

    var timeZone: TimeZone { get }

    func suspendResumeTapped()

    func changeTimeZoneTapped()

    func stopUsingOmnipodTapped()
    
}

extension DashSettingsViewModelProtocol {
    var podOk: Bool {
        switch lifeState {
        case .noPod, .podAlarm, .systemError, .podActivating, .podDeactivating:
            return false
        default:
            return true
        }
    }
    
    var alarmReferenceCode: String? {
        switch lifeState {
        case .podAlarm(let alarm):
            if let alarm = alarm, alarm.alarmCode != .podExpired {
                return alarm.referenceCode
            }
        default:
            break
        }
        return nil
    }
}


