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

class MockDashSettingsViewModel: DashSettingsViewModelProtocol {
        
    var activatedAt: Date?

    var basalDeliveryState: PumpManagerStatus.BasalDeliveryState

    var basalDeliveryRate: BasalDeliveryRate?

    var timeZone: TimeZone {
        return TimeZone.currentFixed
    }

    var lifeState: PodLifeState
    
    var podDetails: PodDetails

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

    init() {
        lifeState = .noPod
        podDetails = MockPodDetails()
        activatedAt = Date().addingTimeInterval(-TimeInterval(days: 1))
        basalDeliveryState = .active(Date())
        basalDeliveryRate = BasalDeliveryRate(absoluteRate: 1.1, netPercent: 1.1)
    }

    func suspendResumeTapped() {
        print("SuspendResumeTapped()")
    }
    
    func changeTimeZoneTapped() {
        print("changeTimeZoneTapped()")
    }

    func stopUsingOmnipodTapped() {
        print("stopUsingOmnipodTapped()")
    }
}

