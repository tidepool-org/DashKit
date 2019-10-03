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

extension DashPumpManager: PumpManagerUI {

    static public func setupViewController() -> (UIViewController & PumpManagerSetupViewController & CompletionNotifying) {
        return DashPumpManagerSetupViewController.instantiateFromStoryboard()
    }

    public func settingsViewController() -> (UIViewController & CompletionNotifying) {
        self.log.debug("Launching settings: podCommState = %@", String(describing: podCommState))
        switch podCommState {
        case .alarm:
            return PodReplacementNavigationController.instantiatePodReplacementFlow(self)
        default:
            if hasActivePod {
                let settings = DashSettingsViewController.instantiateFromStoryboard(pumpManager: self)
                return SettingsNavigationViewController(rootViewController: settings)
            }
            return PodReplacementNavigationController.instantiateSettingsNoPodFlow(self)
        }
    }

    public var smallImage: UIImage? {
        return UIImage(named: "Pod", in: Bundle(for: DashSettingsViewController.self), compatibleWith: nil)!
    }

    public func hudProvider() -> HUDProvider? {
        return DashHUDProvider(pumpManager: self)
    }

    public static func createHUDViews(rawValue: HUDProvider.HUDViewsRawState) -> [BaseHUDView] {
        return DashHUDProvider.createHUDViews(rawValue: rawValue)
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
        setBasalSchedule(dailyItems: viewController.scheduleItems) { (error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(scheduleItems: viewController.scheduleItems, timeZone: self.state.timeZone))
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
