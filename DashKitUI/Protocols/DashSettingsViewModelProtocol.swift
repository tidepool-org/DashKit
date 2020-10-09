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
import DashKit

struct BasalDeliveryRate {
    var absoluteRate: Double
    var netPercent: Double
}

enum DashSettingsViewAlert {
    case suspendError(DashPumpManagerError)
    case resumeError(DashPumpManagerError)
}

protocol DashSettingsViewModelProtocol: ObservableObject, Identifiable {
    
    var activeAlert: DashSettingsViewAlert? { get }
    
    var alertIsPresented: Bool { get set }
    
    var lifeState: PodLifeState { get }

    var activatedAt: Date? { get }
    
    var basalDeliveryState: PumpManagerStatus.BasalDeliveryState? { get }
    
    var basalDeliveryRate: BasalDeliveryRate? { get }

    var podVersion: PodVersionProtocol? { get }
    
    var sdkVersion: String { get }
    
    var pdmIdentifier: String? { get }
    
    var dateFormatter: DateFormatter { get }
    
    var basalRateFormatter: NumberFormatter { get }

    var timeZone: TimeZone { get }

    func suspendDelivery(duration: TimeInterval)

    func resumeDelivery()

    func changeTimeZoneTapped()

    func stopUsingOmnipodTapped()
    
    func doneTapped()    
}

extension DashSettingsViewModelProtocol {
    var podOk: Bool {
        guard basalDeliveryState != nil else { return false }
        
        switch lifeState {
        case .noPod, .podAlarm, .systemError, .podActivating, .podDeactivating:
            return false
        default:
            return true
        }
    }
    
    var systemErrorDescription: String? {
        switch lifeState {
        case .systemError(let systemError):
            return systemError.localizedDescription
        default:
            break
        }
        return nil
    }
}


