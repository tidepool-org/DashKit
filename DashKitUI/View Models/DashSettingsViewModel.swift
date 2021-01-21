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
import PodSDK

struct BasalDeliveryRate {
    var absoluteRate: Double
    var netPercent: Double
}

enum DashSettingsViewAlert {
    case suspendError(DashPumpManagerError)
    case resumeError(DashPumpManagerError)
}

class DashSettingsViewModel: ObservableObject {
    
    @Published var lifeState: PodLifeState
    
    @Published var activatedAt: Date?
    
    @Published var basalDeliveryState: PumpManagerStatus.BasalDeliveryState?

    @Published var basalDeliveryRate: BasalDeliveryRate?

    @Published var activeAlert: DashSettingsViewAlert? = nil {
        didSet {
            if activeAlert != nil {
                alertIsPresented = true
            }
        }
    }

    @Published var alertIsPresented: Bool = false {
        didSet {
            if !alertIsPresented {
                activeAlert = nil
            }
        }
    }
    
    @Published var reservoirLevel: ReservoirLevel?
    
    var podCommManager: PodCommManagerProtocol {
        return pumpManager.unwrappedPodCommManager
    }

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
    
    let reservoirVolumeFormatter = QuantityFormatter(for: .internationalUnit())
    
    var didFinish: (() -> Void)?
    
    private let pumpManager: DashPumpManager
    
    init(pumpManager: DashPumpManager) {
        self.pumpManager = pumpManager
        
        lifeState = pumpManager.lifeState
        activatedAt = pumpManager.podActivatedAt
        basalDeliveryState = pumpManager.status.basalDeliveryState
        basalDeliveryRate = self.pumpManager.basalDeliveryRate
        reservoirLevel = self.pumpManager.reservoirLevel
        pumpManager.addPodStatusObserver(self, queue: DispatchQueue.main)
    }
    
    func changeTimeZoneTapped() {
        pumpManager.setTime { (error) in
            // TODO: handle error
            self.lifeState = self.pumpManager.lifeState            
        }
    }
    
    func doneTapped() {
        self.didFinish?()
    }
    
    func stopUsingOmnipodTapped() {
        self.pumpManager.notifyDelegateOfDeactivation {
            DispatchQueue.main.async {
                self.didFinish?()
            }
        }
    }
    
    func suspendDelivery(duration: TimeInterval) {
        guard let reminder = try? StopProgramReminder(value: duration) else {
            assertionFailure("Invalid StopProgramReminder duration of \(duration)")
            return
        }

        pumpManager.suspendDelivery(withReminder: reminder) { (error) in
            if let error = error {
                self.activeAlert = .suspendError(error)
            }
        }
    }
    
    func resumeDelivery() {
        pumpManager.resumeInsulinDelivery { (error) in
            if let error = error {
                self.activeAlert = .resumeError(error)
            }
        }
    }
}

extension DashSettingsViewModel {
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

extension DashSettingsViewModel: PodStatusObserver {
    func didUpdatePodStatus() {
        lifeState = self.pumpManager.lifeState
        basalDeliveryState = self.pumpManager.status.basalDeliveryState
        basalDeliveryRate = self.pumpManager.basalDeliveryRate
        reservoirLevel = self.pumpManager.reservoirLevel
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
                let timeActive = dateGenerator().timeIntervalSince(activationTime)
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
        let scheduledRate = state.basalProgram.currentRate(using: calendar, at: dateGenerator()).basalRateUnitsPerHour
        let maximumTempBasalRate = state.maximumTempBasalRate
        
        var netBasalPercent: Double
        var absoluteRate: Double

        if let tempBasal = state.unfinalizedTempBasal, !tempBasal.isFinished(at: dateGenerator()) {
            
            absoluteRate = tempBasal.rate
            
            let rate = tempBasal.rate - scheduledRate
            
            if rate < 0 {
                netBasalPercent = rate / scheduledRate
            } else {
                netBasalPercent = rate / (maximumTempBasalRate - scheduledRate )
            }
        } else {
            switch state.suspendState {
            case .resumed:
                absoluteRate = scheduledRate
                netBasalPercent = 0
            case .suspended:
                absoluteRate = 0
                netBasalPercent = -1
            case .none:
                return nil
            }
        }
        
        return BasalDeliveryRate(absoluteRate: absoluteRate, netPercent: netBasalPercent)
    }
}

extension PumpManagerStatus.BasalDeliveryState {
    var headerText: String {
        switch self {
        case .active, .suspending:
             return LocalizedString("Scheduled Basal", comment: "Header text for basal delivery view when scheduled basal active")
        case .tempBasal:
             return LocalizedString("Temporary Basal", comment: "Header text for basal delivery view when temporary basal running")
        case .suspended, .resuming:
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
            return LocalizedString("Suspending insulin delivery...", comment: "Text for suspend resume button when insulin delivery is suspending")
        case .suspended:
            return LocalizedString("Resume Insulin Delivery", comment: "Text for suspend resume button when insulin delivery is suspended")
        case .resuming:
            return LocalizedString("Resuming insulin delivery...", comment: "Text for suspend resume button when insulin delivery is resuming")
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
}
