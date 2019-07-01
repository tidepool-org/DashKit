//
//  NoActivePodViewController.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 7/1/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import DashKit
import LoopKit
import LoopKitUI


// Not a SetupTableViewController
class NoActivePodViewController: UIViewController {

    var pumpManager: DashPumpManager! {
        didSet {
            pumpManager.addStatusObserver(self, queue: .main)
        }
    }

    static public func instantiateFromStoryboard(pumpManager: DashPumpManager) -> NoActivePodViewController {

        let storyboard = UIStoryboard(name: "DashPumpManager", bundle: Bundle(for: DashPumpManagerSetupViewController.self))
        let settings = storyboard.instantiateViewController(withIdentifier: "NoActivePod") as! NoActivePodViewController
        settings.pumpManager = pumpManager
        return settings
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed(_:)))

    }

    @IBAction func newPodButtonPressed(_: Any) {
        let vc = PodReplacementNavigationController.instantiateNewPodFlow(pumpManager)
        vc.completionDelegate = self
        self.navigationController?.present(vc, animated: true, completion: nil)
    }

    @IBAction open func cancelButtonPressed(_: Any) {
        done()
    }

    @IBAction open func deletePumpManagerButtonPressed(_: Any) {
        let confirmVC = UIAlertController(pumpManagerDeletionHandler: {
            self.pumpManager.notifyDelegateOfDeactivation {
                DispatchQueue.main.async {
                    self.done()
                }
            }
        })

        present(confirmVC, animated: true)
    }

    private func done() {
        if let nav = navigationController as? SettingsNavigationViewController {
            nav.notifyComplete()
        }
    }
}

extension NoActivePodViewController: PumpManagerStatusObserver {
    func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus) {
    }
}

extension NoActivePodViewController: CompletionDelegate {
    func completionNotifyingDidComplete(_ object: CompletionNotifying) {
        if let vc = object as? UIViewController {
            vc.dismiss(animated: false, completion: nil)
        }
    }
}

extension NoActivePodViewController: PodStatusObserver {
    func didUpdatePodStatus() {
        //tableView.reloadData()
    }
}

private extension UIAlertController {
    convenience init(pumpManagerDeletionHandler handler: @escaping () -> Void) {
        self.init(
            title: nil,
            message: LocalizedString("Are you sure you want to stop using Omnipod with Loop?", comment: "Confirmation message for removing Omnipod PumpManager"),
            preferredStyle: .actionSheet
        )

        addAction(UIAlertAction(
            title: LocalizedString("Stop using Omnipod", comment: "Button title to delete Omnipod PumpManager"),
            style: .destructive,
            handler: { (_) in
                handler()
        }
        ))

        let cancel = LocalizedString("Cancel", comment: "The title of the cancel action in an action sheet")
        addAction(UIAlertAction(title: cancel, style: .cancel, handler: nil))
    }
}
