//
//  ReplacePodViewController.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 5/10/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import UIKit
import LoopKitUI
import DashKit
import PodSDK
import os.log

class ReplacePodViewController: SetupTableViewController {
    
    class func instantiateFromStoryboard(_ pumpManager: DashPumpManager, navigator: DashUINavigator) -> ReplacePodViewController {
        let vc = UIStoryboard(name: "DashPumpManager", bundle: Bundle(for: ReplacePodViewController.self)).instantiateViewController(withIdentifier: "ReplacePodViewController") as! ReplacePodViewController
        vc.pumpManager = pumpManager
        vc.navigator = navigator
        return vc
    }

    weak var navigator: DashUINavigator?

    private let log = OSLog(category: "ReplacePodViewController")

    enum PodReplacementReason {
        case normal
        case alarm(AlarmCode)
        case canceledPairingBeforeApplication
        case canceledPairing
    }

    var replacementReason: PodReplacementReason = .normal {
        didSet {
            updateButtonTint()
            switch replacementReason {
            case .normal:
            break // Text set in interface builder
            case .alarm(let alarmCode):
                
                instructionsLabel.text = String(format: LocalizedString("%1$@. %2$@", comment: "Format string providing instructions for replacing pod due to a fault. (1: The alarm code notification title) (2: The alarm code notification body)"), alarmCode.notificationTitle, alarmCode.notificationBody)
            case .canceledPairingBeforeApplication:
                instructionsLabel.text = LocalizedString("Incompletely set up pod must be deactivated before pairing with a new one. Please deactivate and discard pod.", comment: "Instructions when deactivating pod that has been paired, but not attached.")
            case .canceledPairing:
                instructionsLabel.text = LocalizedString("Incompletely set up pod must be deactivated before pairing with a new one. Please deactivate and remove pod.", comment: "Instructions when deactivating pod that has been paired and possibly attached.")
            }

            tableView.reloadData()
        }
    }

    var pumpManager: DashPumpManager!

    // MARK: -

    @IBOutlet weak var activityIndicator: SetupIndicatorView!

    @IBOutlet weak var loadingLabel: UILabel!

    @IBOutlet weak var instructionsLabel: UILabel!


    private var tryCount: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        continueState = .initial
        
        let podState = pumpManager.podCommState
        switch podState {
        case .alarm:
           let alarmCode: AlarmCode = pumpManager.state.alarmCode ?? .other
           self.replacementReason = .alarm(alarmCode)
        case .activating:
           self.replacementReason = .canceledPairingBeforeApplication
        case .deactivating:
           self.replacementReason = .canceledPairing
        default:
           self.replacementReason = .normal
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard continueState != .deactivating else {
            return
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }


    // MARK: - Navigation

    private enum State {
        case initial
        case deactivating
        case deactivationFailed
        case continueAfterFailure
        case ready
    }

    private var continueState: State = .initial {
        didSet {
            updateButtonTint()
            switch continueState {
            case .initial:
                activityIndicator.state = .hidden
                footerView.primaryButton.isEnabled = true
                footerView.primaryButton.setDeactivateTitle()
            case .deactivating:
                activityIndicator.state = .indeterminantProgress
                footerView.primaryButton.isEnabled = false
                lastError = nil
            case .deactivationFailed:
                activityIndicator.state = .hidden
                footerView.primaryButton.isEnabled = true
                footerView.primaryButton.setRetryTitle()
            case .continueAfterFailure:
                activityIndicator.state = .hidden
                footerView.primaryButton.isEnabled = true
                footerView.primaryButton.setDiscardTitle()
                tableView.beginUpdates()
                loadingLabel.text = LocalizedString("Unable to deactivate pod. Discard pod and pair a new one.", comment: "Instructions when pod cannot be deactivated")
                loadingLabel.isHidden = false
                tableView.endUpdates()
            case .ready:
                navigationItem.rightBarButtonItem = nil
                activityIndicator.state = .completed
                footerView.primaryButton.isEnabled = true
                footerView.primaryButton.resetTitle()
                footerView.primaryButton.tintColor = nil
                lastError = nil
            }
        }
    }

    private var lastError: Error? {
        didSet {
            guard oldValue != nil || lastError != nil else {
                return
            }

            var errorText = lastError?.localizedDescription

            if let error = lastError as? LocalizedError {
                let localizedText = [error.errorDescription, error.failureReason, error.recoverySuggestion].compactMap({ $0 }).joined(separator: ". ") + "."

                if !localizedText.isEmpty {
                    errorText = localizedText
                }
            }

            tableView.beginUpdates()
            loadingLabel.text = errorText
            loadingLabel.isHidden = (errorText == nil)
            tableView.endUpdates()
        }
    }

    override func continueButtonPressed(_ sender: Any) {
        switch continueState {
        case .ready:
            navigator?.navigateTo(.pairPod)
        case .continueAfterFailure:
            pumpManager.discardPod { (_) in
                DispatchQueue.main.async {
                    self.lastError = nil
                    self.continueState = .ready
                }
            }
        case .initial, .deactivationFailed:
            continueState = .deactivating
            deactivate()
        case .deactivating:
            break
        }
    }

    func deactivate() {
        tryCount += 1

        pumpManager.deactivatePod { (result) in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    if self.tryCount > 1 {
                        self.continueState = .continueAfterFailure
                    } else {
                        self.log.error("deactivatePod returned error: %{public}@", String(describing: error))
                        self.lastError = error
                        self.continueState = .deactivationFailed
                    }
                }
            case .success:
                self.pumpManager.discardPod(completion: { (result) in
                    switch result {
                    case .failure(let error):
                        self.log.error("discardPod returned error: %{public}@", String(describing: error))
                    case .success:
                        break
                    }
                    // Continue in either case, as we need a continue path for the user.
                    DispatchQueue.main.async {
                        self.lastError = nil
                        self.continueState = .ready
                    }
                })
            }
        }
    }

    override func cancelButtonPressed(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }

    private func updateButtonTint() {
        let buttonTint: UIColor?
        if case .normal = replacementReason, case .initial = continueState {
            buttonTint = .deleteColor
        } else {
            buttonTint = nil
        }
        footerView.primaryButton.tintColor = buttonTint
    }

}

private extension SetupButton {
    func setDeactivateTitle() {
        setTitle(LocalizedString("Deactivate Pod", comment: "Button title for pod deactivation"), for: .normal)
    }

    func setRetryTitle() {
        setTitle(LocalizedString("Retry Pod Deactivation", comment: "Button title for retrying pod deactivation"), for: .normal)
    }
    
    func setDiscardTitle() {
        setTitle(LocalizedString("Discard Pod", comment: "Button title to discard pod"), for: .normal)
    }
}


