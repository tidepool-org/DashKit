//
//  PodReplacementNavigationController.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 5/16/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import DashKit
import LoopKitUI

class PodReplacementNavigationController: UINavigationController, UINavigationControllerDelegate, CompletionNotifying {

    weak var completionDelegate: CompletionDelegate?

    class func instantiatePodReplacementFlow(_ pumpManager: DashPumpManager) -> PodReplacementNavigationController {
        let vc = UIStoryboard(name: "DashPumpManager", bundle: Bundle(for: PodReplacementNavigationController.self)).instantiateViewController(withIdentifier: "PodReplacementFlow") as! PodReplacementNavigationController
        vc.pumpManager = pumpManager
        return vc
    }

    class func instantiateNewPodFlow(_ pumpManager: DashPumpManager) -> PodReplacementNavigationController {
        let vc = UIStoryboard(name: "DashPumpManager", bundle: Bundle(for: PodReplacementNavigationController.self)).instantiateViewController(withIdentifier: "NewPodFlow") as! PodReplacementNavigationController
        vc.pumpManager = pumpManager
        return vc
    }

    class func instantiateInsertCannulaFlow(_ pumpManager: DashPumpManager) -> PodReplacementNavigationController {
        let vc = UIStoryboard(name: "DashPumpManager", bundle: Bundle(for: PodReplacementNavigationController.self)).instantiateViewController(withIdentifier: "InsertCannulaFlow") as! PodReplacementNavigationController
        vc.pumpManager = pumpManager
        return vc
    }

    private(set) var pumpManager: DashPumpManager!

    override func viewDidLoad() {
        super.viewDidLoad()

        delegate = self
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {

        if let setupViewController = viewController as? SetupTableViewController {
            setupViewController.delegate = self
        }

        switch viewController {
        case let vc as ReplacePodViewController:
            vc.pumpManager = pumpManager
        case let vc as PairPodSetupViewController:
            vc.pumpManager = pumpManager
        case let vc as InsertCannulaSetupViewController:
            vc.pumpManager = pumpManager
        case let vc as PodSetupCompleteViewController:
            vc.pumpManager = pumpManager
        default:
            break
        }

    }

    func completeSetup() {
        completionDelegate?.completionNotifyingDidComplete(self)
    }
}

extension PodReplacementNavigationController: SetupTableViewControllerDelegate {
    func setupTableViewControllerCancelButtonPressed(_ viewController: SetupTableViewController) {
        self.dismiss(animated: true, completion: nil)
    }
}
