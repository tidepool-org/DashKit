//
//  DashPumpManagerSetupViewController.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 4/19/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import LoopKit
import LoopKitUI
import PodSDK
import DashKit

public class DashPumpManagerSetupViewController: UINavigationController, PumpManagerSetupViewController, UINavigationControllerDelegate, CompletionNotifying {

    public var setupDelegate: PumpManagerSetupViewControllerDelegate?

    public var maxBasalRateUnitsPerHour: Double?

    public var maxBolusUnits: Double?

    public var basalSchedule: BasalRateSchedule?

    public var completionDelegate: CompletionDelegate?

    private(set) var pumpManager: DashPumpManager?

    class func instantiateFromStoryboard() -> DashPumpManagerSetupViewController {
        let storyboard = UIStoryboard(name: "DashPumpManager", bundle: Bundle(for: DashPumpManagerSetupViewController.self))

        if RegistrationManager.shared.isRegistered() {
            return storyboard.instantiateViewController(withIdentifier: "SetupWithoutRegistration") as! DashPumpManagerSetupViewController
        } else {
            return storyboard.instantiateViewController(withIdentifier: "SetupWithRegistration") as! DashPumpManagerSetupViewController
        }
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOSApplicationExtension 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }

        delegate = self
    }


    /*
     1. Registration (if needed)

     2. Basal Rates & Delivery Limits

     3. Pod Pairing/Priming/Cannula Insertion

     4. Pod Setup Complete
     */

    public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {

        if let setupViewController = viewController as? SetupTableViewController {
            setupViewController.delegate = self
        }

        switch viewController {
        case let vc as PairPodSetupViewController:
            if let basalRateSchedule = basalSchedule, let pumpManagerState = DashPumpManagerState(basalRateSchedule: basalRateSchedule) {
                let pumpManager = DashPumpManager(state: pumpManagerState)
                vc.pumpManager = pumpManager
                self.pumpManager = pumpManager
                setupDelegate?.pumpManagerSetupViewController(self, didSetUpPumpManager: pumpManager)
            }
        case let vc as ReplacePodViewController:
            vc.pumpManager = pumpManager
        case let vc as InsertCannulaSetupViewController:
            vc.pumpManager = pumpManager
        case let vc as PodSetupCompleteViewController:
            vc.pumpManager = pumpManager
        default:
            break
        }

    }

    open func finishedSetup() {
        if let pumpManager = pumpManager {

            let settings = DashSettingsViewController.instantiateFromStoryboard(pumpManager: pumpManager)
            setViewControllers([settings], animated: true)
        }
    }

    public func finishedSettingsDisplay() {
        completionDelegate?.completionNotifyingDidComplete(self)
    }

}

extension DashPumpManagerSetupViewController: SetupTableViewControllerDelegate {
    public func setupTableViewControllerCancelButtonPressed(_ viewController: SetupTableViewController) {
        completionDelegate?.completionNotifyingDidComplete(self)
    }
}
