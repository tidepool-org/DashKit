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

public enum DashPumpManagerError: Error {
    case missingSettings
}

extension DashPumpManager: PumpManagerUI {

    static public func setupViewController() -> (UIViewController & PumpManagerSetupViewController & CompletionNotifying) {
        return DashPumpManagerSetupViewController.instantiateFromStoryboard()
    }

    public func settingsViewController() -> (UIViewController & CompletionNotifying) {
        switch podCommState {
        case .noPod:
            return PodReplacementNavigationController.instantiateNewPodFlow(self)
        case .alarm:
            return PodReplacementNavigationController.instantiatePodReplacementFlow(self)
        default:
            let rootViewController: UIViewController
            if hasActivePod {
                rootViewController = DashSettingsViewController.instantiateFromStoryboard(pumpManager: self)
            } else {
                rootViewController = NoActivePodViewController.instantiateFromStoryboard(pumpManager: self)
            }
            let nav = SettingsNavigationViewController(rootViewController: rootViewController)
            return nav
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
        guard let maxBasalRate = viewController.maximumBasalRatePerHour,
            let maxBolus = viewController.maximumBolus else
        {
            completion(.failure(DashPumpManagerError.missingSettings))
            return
        }

        completion(.success(maximumBasalRatePerHour: maxBasalRate, maximumBolus: maxBolus))
    }

    public func syncButtonTitle(for viewController: DeliveryLimitSettingsTableViewController) -> String {
        return LocalizedString("Save", comment: "Title of button to save delivery limit settings")    }

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
//        let newSchedule = BasalSchedule(repeatingScheduleValues: viewController.scheduleItems)
//        setBasalSchedule(newSchedule) { (error) in
//            if let error = error {
//                completion(.failure(error))
//            } else {
//                completion(.success(scheduleItems: viewController.scheduleItems, timeZone: self.state.timeZone))
//            }
//        }
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
