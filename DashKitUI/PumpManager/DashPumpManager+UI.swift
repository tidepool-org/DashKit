//
//  DashPumpManager+UI.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 4/19/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI
import DashKit
import SwiftUI

extension DashPumpManager: PumpManagerUI {
    

    public static var onboardingImage: UIImage? {
        return UIImage(named: "Onboarding", in: Bundle(for: DashSettingsViewModel.self), compatibleWith: nil)
    }
        
    public static func setupViewController(initialSettings settings: PumpManagerSetupSettings, bluetoothProvider: BluetoothProvider, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool, allowedInsulinTypes: [InsulinType]) -> SetupUIResult<PumpManagerViewController, PumpManagerUI> {
        let vc = DashUICoordinator(colorPalette: colorPalette, pumpManagerType: self, basalSchedule: settings.basalSchedule, allowDebugFeatures: allowDebugFeatures)
        return .userInteractionRequired(vc)
    }
        
    public func settingsViewController(bluetoothProvider: BluetoothProvider, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool, allowedInsulinTypes: [InsulinType]) -> PumpManagerViewController {
        return DashUICoordinator(pumpManager: self, colorPalette: colorPalette, allowDebugFeatures: allowDebugFeatures)
    }
    
    public func deliveryUncertaintyRecoveryViewController(colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool) -> (UIViewController & CompletionNotifying) {
        return DashUICoordinator(pumpManager: self, colorPalette: colorPalette, allowDebugFeatures: allowDebugFeatures)
    }
    
    public var smallImage: UIImage? {
        return UIImage(named: "Pod", in: Bundle(for: DashSettingsViewModel.self), compatibleWith: nil)!
    }

    public func hudProvider(bluetoothProvider: BluetoothProvider, colorPalette: LoopUIColorPalette, allowedInsulinTypes: [InsulinType]) -> HUDProvider? {
        return DashHUDProvider(pumpManager: self, bluetoothProvider: bluetoothProvider, colorPalette: colorPalette, allowedInsulinTypes: allowedInsulinTypes)
    }

    public static func createHUDView(rawValue: HUDProvider.HUDViewRawState) -> BaseHUDView? {
        return DashHUDProvider.createHUDView(rawValue: rawValue)
    }

}

public enum DashStatusBadge: DeviceStatusBadge {
    case timeSyncNeeded
    
    public var image: UIImage? {
        switch self {
        case .timeSyncNeeded:
            return UIImage(systemName: "clock.fill")
        }
    }
    
    public var state: DeviceStatusBadgeState {
        switch self {
        case .timeSyncNeeded:
            return .warning
        }
    }
}



// MARK: - PumpStatusIndicator
extension DashPumpManager {
    
    public var pumpStatusHighlight: DeviceStatusHighlight? {
        return buildPumpStatusHighlight(for: state)
    }
    
    public var pumpLifecycleProgress: DeviceLifecycleProgress? {
        return buildPumpLifecycleProgress(for: state)
    }
    
    public var pumpStatusBadge: DeviceStatusBadge? {
        if isClockOffset {
            return DashStatusBadge.timeSyncNeeded
        } else {
            return nil
        }
    }
}
