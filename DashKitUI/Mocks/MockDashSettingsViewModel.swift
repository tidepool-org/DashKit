//
//  MockDashSettingsViewModel.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/8/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import SwiftUI
import LoopKit
import HealthKit
import DashKit

class MockDashSettingsViewModel: DashSettingsViewModelProtocol {
    var activatedAt: Date?

    var basalDeliveryState: PumpManagerStatus.BasalDeliveryState? = .suspended(Date())

    var basalDeliveryRate: BasalDeliveryRate? = BasalDeliveryRate(absoluteRate: 1.1, netPercent: 1.1)

    var timeZone: TimeZone {
        return TimeZone.currentFixed
    }

    var lifeState: PodLifeState = .noPod
    
    var podVersion: PodVersionProtocol? = MockPodVersion(lotNumber: 1, sequenceNumber: 1, majorVersion: 1, minorVersion: 1, interimVersion: 1, bleMajorVersion: 1, bleMinorVersion: 1, bleInterimVersion: 1)
    
    var sdkVersion: String = "1.2.3"

    var pdmIdentifier: String?
    
    var activeAlert: DashSettingsViewAlert? = nil {
        didSet {
            if activeAlert != nil {
                alertIsPresented = true
            }
        }
    }
    
    @Published var alertIsPresented: Bool = false

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
        numberFormatter.minimumFractionDigits = unit.preferredFractionDigits
        numberFormatter.maximumFractionDigits = unit.preferredFractionDigits
        return numberFormatter
    }()

    func suspendDelivery(duration: TimeInterval) {
        basalDeliveryState = .suspending
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.basalDeliveryState = .suspended(Date())
            self.basalDeliveryRate = nil
        }
    }
    
    func resumeDelivery() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.basalDeliveryState = .active(Date())
            self.basalDeliveryRate = BasalDeliveryRate(absoluteRate: 1.0, netPercent: 1.0)
        }
    }
    
    func changeTimeZoneTapped() {
        print("changeTimeZoneTapped()")
    }

    func stopUsingOmnipodTapped() {
        print("stopUsingOmnipodTapped()")
    }
    
    func doneTapped() {
        print("doneTapped()")
    }

    static func noPod() -> MockDashSettingsViewModel {
        return MockDashSettingsViewModel()
    }
    
    static func livePod() -> MockDashSettingsViewModel {
        let model = MockDashSettingsViewModel()
        model.basalDeliveryState = .active(Date())
        model.lifeState = .timeRemaining(.days(2.5))
        return model
    }
}

