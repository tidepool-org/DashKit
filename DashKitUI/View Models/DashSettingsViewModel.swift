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
import HealthKit

class DashSettingsViewModel: DashSettingsViewModelProtocol {
    
    @Published var lifeState: PodLifeState
    
    @Published var activatedAt: Date?
    
    @Published var basalDeliveryState: PumpManagerStatus.BasalDeliveryState

    @Published var basalDeliveryRate: BasalDeliveryRate?
    
    var timeZone: TimeZone {
        return pumpManager.status.timeZone
    }
    
    var podVersion: PodVersionProtocol? {
        return self.pumpManager.podVersion
    }
    
    var sdkVersion: String {
        return self.pumpManager.sdkVersion
    }
    
    var pdmIdentifier: String? {
        return self.pumpManager.pdmIdentifier
    }
    
    
    let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .medium
        dateFormatter.doesRelativeDateFormatting = true
        return dateFormatter
    }()
    
    let basalRateFormatter: NumberFormatter = {
        let unit = HKUnit.internationalUnit()
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 1
        numberFormatter.minimumIntegerDigits = 1
        return numberFormatter
    }()
    
    var didFinish: (() -> Void)?
    
    private let pumpManager: DashPumpManager
    
    init(pumpManager: DashPumpManager) {
        self.pumpManager = pumpManager
        
        lifeState = pumpManager.lifeState
        activatedAt = pumpManager.podActivatedAt
        basalDeliveryState = pumpManager.status.basalDeliveryState
        basalDeliveryRate = self.pumpManager.basalDeliveryRate
        
        pumpManager.addStatusObserver(self, queue: DispatchQueue.main)
    }
    
    func suspendResumeTapped() {
        
        switch basalDeliveryState {
        case .active, .tempBasal:
            pumpManager.suspendDelivery { (error) in
                // TODO: Display error
            }
        case .suspended:
            pumpManager.resumeDelivery { (error) in
                // TODO: Display error
            }
        default:
            break
        }
    }
    
    func changeTimeZoneTapped() {
        pumpManager.setTime { (error) in
            // TODO: handle error
            self.lifeState = self.pumpManager.lifeState            
        }
    }
    
    func stopUsingOmnipodTapped() {
        self.pumpManager.notifyDelegateOfDeactivation {
            DispatchQueue.main.async {
                self.didFinish?()
            }
        }
    }
}

extension DashSettingsViewModel: PumpManagerStatusObserver {
    func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus) {
        lifeState = self.pumpManager.lifeState
        basalDeliveryState = status.basalDeliveryState
        basalDeliveryRate = self.pumpManager.basalDeliveryRate
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
                    return .expiredFor(timeActive - Pod.lifetime)
                }
            } else {
                return .podDeactivating
            }
        case .systemError(let error):
            return .systemError(error)
        }
    }
    
    var basalDeliveryRate: BasalDeliveryRate? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = state.timeZone
        let scheduledRate = state.basalProgram.currentRate(using: calendar, at: Date()).basalRateUnitsPerHour
        let maximumTempBasalRate = state.maximumTempBasalRate
        
        guard let netBasalPercent = status.basalDeliveryState.netBasalPercent(
            scheduledRate: scheduledRate,
            maximumTempBasalRate: maximumTempBasalRate
        ) else {
            return nil
        }
        
        var absoluteRate: Double
        switch status.basalDeliveryState {
        case .tempBasal(let dose):
            absoluteRate = dose.unitsPerHour
        case .suspended:
            absoluteRate = 0
        default:
            absoluteRate = scheduledRate
        }
        return BasalDeliveryRate(absoluteRate: absoluteRate, netPercent: netBasalPercent)
    }
}

extension PumpManagerStatus.BasalDeliveryState {
    var headerText: String {
        switch self {
        case .active:
             return LocalizedString("Scheduled Basal", comment: "Header text for basal delivery view when scheduled basal active")
        case .tempBasal:
             return LocalizedString("Temporary Basal", comment: "Header text for basal delivery view when temporary basal running")
        case .suspended:
            return LocalizedString("Basal Suspended", comment: "Header text for basal delivery view when basal is suspended")
        default:
            return ""
        }
    }
    
    var suspendResumeActionText: String {
        switch self {
        case .active, .tempBasal, .cancelingTempBasal, .initiatingTempBasal:
            return LocalizedString("Suspend Insulin Delivery", comment: "Text for suspend resume button when insulin delivery active")
        case .suspending:
            return LocalizedString("Suspending Delivery", comment: "Text for suspend resume button when insulin delivery is suspending")
        case .suspended:
            return LocalizedString("Resume Insulin Delivery", comment: "Text for suspend resume button when insulin delivery is suspended")
        case .resuming:
            return LocalizedString("Resuming Insulin Delivery", comment: "Text for suspend resume button when insulin delivery is resuming")
        }
    }
    
    var transitioning: Bool {
        switch self {
        case .suspending, .resuming:
            return true
        default:
            return false
        }
    }
    
    var suspendResumeActionColor: Color {
        switch self {
        case .suspending, .resuming:
            return Color.secondary
        default:
            return Color.accentColor
        }
    }
    
    func netBasalPercent(scheduledRate: Double, maximumTempBasalRate: Double) -> Double? {
        switch self {
        case .tempBasal(let dose):
            let rate = dose.unitsPerHour - scheduledRate
            
            if rate < 0 {
                return rate / dose.unitsPerHour
            } else {
                return rate / (maximumTempBasalRate - dose.unitsPerHour )
            }
        case .active:
            return 0
        case .suspended:
            return -1
        default:
            return nil
        }
    }
}
