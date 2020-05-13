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

    var basalDeliveryState: PumpManagerStatus.BasalDeliveryState

    var basalDeliveryRate: BasalDeliveryRate?

    var timeZone: TimeZone {
        return TimeZone.currentFixed
    }

    var lifeState: PodLifeState
    
    var podVersion: PodVersionProtocol?
    
    var sdkVersion: String

    var pdmIdentifier: String?

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
        podVersion = MockPodVersion(lotNumber: 1, sequenceNumber: 1, majorVersion: 1, minorVersion: 1, interimVersion: 1, bleMajorVersion: 1, bleMinorVersion: 1, bleInterimVersion: 1)
        activatedAt = Date().addingTimeInterval(-TimeInterval(days: 1))
        basalDeliveryState = .active(Date())
        basalDeliveryRate = BasalDeliveryRate(absoluteRate: 1.1, netPercent: 1.1)
        sdkVersion = "1.2.3"
        pdmIdentifier = "1.2.3"
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
    
    func doneTapped() {
        print("doneTapped()")
    }
}

