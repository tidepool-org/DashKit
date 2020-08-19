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
    public func deliveryUncertaintyRecoveryView() -> AnyView {
        return AnyView(Text("Hello"))
    }
    

    static public func setupViewController(insulinTintColor: Color, guidanceColors: GuidanceColors) -> (UIViewController & PumpManagerSetupViewController & CompletionNotifying) {
        return DashUICoordinator(insulinTintColor: insulinTintColor, guidanceColors: guidanceColors)
    }

    public func settingsViewController(insulinTintColor: Color, guidanceColors: GuidanceColors) -> (UIViewController & CompletionNotifying) {
        return DashUICoordinator(pumpManager: self, insulinTintColor: insulinTintColor, guidanceColors: guidanceColors)
    }

    public var smallImage: UIImage? {
        return UIImage(named: "Pod", in: Bundle(for: DashSettingsViewModel.self), compatibleWith: nil)!
    }

    public func hudProvider(insulinTintColor: Color, guidanceColors: GuidanceColors) -> HUDProvider? {
        return DashHUDProvider(pumpManager: self, insulinTintColor: insulinTintColor, guidanceColors: guidanceColors)
    }

    public static func createHUDView(rawValue: HUDProvider.HUDViewRawState) -> LevelHUDView? {
        return DashHUDProvider.createHUDView(rawValue: rawValue)
    }

}

// MARK: - DeliveryLimitSettingsTableViewControllerSyncSource
extension DashPumpManager {
    public func syncDeliveryLimitSettings(for viewController: DeliveryLimitSettingsTableViewController, completion: @escaping (DeliveryLimitSettingsResult) -> Void) {
        guard let maximumBasalRatePerHour = viewController.maximumBasalRatePerHour,
            let maximumBolus = viewController.maximumBolus else
        {
            completion(.failure(DashPumpManagerError.missingSettings))
            return
        }

        completion(.success(maximumBasalRatePerHour: maximumBasalRatePerHour, maximumBolus: maximumBolus))
    }

    public func syncButtonTitle(for viewController: DeliveryLimitSettingsTableViewController) -> String {
        return LocalizedString("Save", comment: "Title of button to save delivery limit settings")
    }

    public func syncButtonDetailText(for viewController: DeliveryLimitSettingsTableViewController) -> String? {
        return nil
    }

    public func deliveryLimitSettingsTableViewControllerIsReadOnly(_ viewController: DeliveryLimitSettingsTableViewController) -> Bool {
        return false
    }
}

// MARK: - BasalScheduleTableViewControllerSyncSource
extension DashPumpManager {

    public func syncScheduleValues(for viewController: BasalScheduleTableViewController, completion: @escaping (SyncBasalScheduleResult<Double>) -> Void) {
        syncBasalRateSchedule(items: viewController.scheduleItems) { result in
            switch result {
            case .success(let schedule):
                completion(.success(scheduleItems: schedule.items, timeZone: schedule.timeZone))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func syncButtonTitle(for viewController: BasalScheduleTableViewController) -> String {
        if self.hasActivePod {
            return LocalizedString("Sync With Pod", comment: "Title of button to sync basal profile from pod")
        } else {
            return LocalizedString("Save", comment: "Title of button to sync basal profile when no pod paired")
        }
    }

    public func syncButtonDetailText(for viewController: BasalScheduleTableViewController) -> String? {
        return nil
    }

    public func basalScheduleTableViewControllerIsReadOnly(_ viewController: BasalScheduleTableViewController) -> Bool {
        return false
    }
}
