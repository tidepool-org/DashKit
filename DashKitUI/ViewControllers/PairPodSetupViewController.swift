//
//  PairPodSetupViewController.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 5/10/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation


import UIKit
import LoopKit
import LoopKitUI
import DashKit
import SwiftGif
import PodSDK

class PairPodSetupViewController: SetupTableViewController {

    var pumpManager: DashPumpManager!

    // MARK: -

    @IBOutlet weak var activityIndicator: SetupIndicatorView!

    @IBOutlet weak var loadingLabel: UILabel!

    @IBOutlet weak var imageView: UIImageView!

    private var loadingText: String? {
        didSet {
            tableView.beginUpdates()
            loadingLabel.text = loadingText

            let isHidden = (loadingText == nil)
            loadingLabel.isHidden = isHidden
            tableView.endUpdates()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        continueState = .initial

        if let dataAsset = NSDataAsset(name: "Fill Pod", bundle: Bundle(for: PairPodSetupViewController.self)) {
            let image = UIImage.gif(data: dataAsset.data)
            imageView.image = image
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if case .pairing = continueState {
            return
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - State

    private enum State {
        case initial
        case pairing
        case priming(finishTime: TimeInterval)
        case fault
        case ready
    }

    private var continueState: State = .initial {
        didSet {
            switch continueState {
            case .initial:
                activityIndicator.state = .hidden
                footerView.primaryButton.isEnabled = true
                if lastError == nil {
                    footerView.primaryButton.setPairTitle()
                } else {
                    footerView.primaryButton.setTitle(LocalizedString("Retry", comment: "Button title to retry pairing"), for: .normal)
                }
            case .pairing:
                activityIndicator.state = .indeterminantProgress
                footerView.primaryButton.isEnabled = false
                footerView.primaryButton.setPairTitle()
                lastError = nil
                loadingText = LocalizedString("Pairing with Pod...", comment: "The text of the loading label when pairing")
            case .priming(let finishTime):
                activityIndicator.state = .timedProgress(finishTime: CACurrentMediaTime() + finishTime)
                footerView.primaryButton.isEnabled = false
                footerView.primaryButton.setPairTitle()
                lastError = nil
                loadingText = LocalizedString("Priming Pod...", comment: "The text of the loading label when priming")
            case .fault:
                activityIndicator.state = .hidden
                footerView.primaryButton.isEnabled = true
                footerView.primaryButton.setDeactivateTitle()
            case .ready:
                activityIndicator.state = .completed
                footerView.primaryButton.isEnabled = true
                footerView.primaryButton.resetTitle()
                lastError = nil
                loadingText = LocalizedString("Primed", comment: "The text of the loading label when pod is primed")
            }
        }
    }

    private var lastError: PodSDK.PodCommError? {
        didSet {
            guard oldValue != nil || lastError != nil else {
                return
            }

            var errorText = lastError?.localizedDescription

            if let error = lastError {
                let localizedText = [error.errorDescription, error.failureReason, error.recoverySuggestion].compactMap({ $0 }).joined(separator: ". ") + "."

                if !localizedText.isEmpty {
                    errorText = localizedText
                }

                if case .podNotAvailable = error {
                    continueState = .initial // Always retry
                } else if case .activationError(.moreThanOnePodAvailable) = error {
                    continueState = .initial // Always retry
                } else {
                    // On first error: retry. On second, fault (discard pod)
                    continueState = oldValue == nil ? State.initial : State.fault
                }

            } else if lastError != nil {
                continueState = .initial
            }

            loadingText = errorText

        }
    }

    // MARK: - Navigation

    private func navigateToReplacePod() {
        performSegue(withIdentifier: "ReplacePod", sender: nil)
    }

    override func continueButtonPressed(_ sender: Any) {
        switch continueState {
        case .initial:
            pair()
        case .ready:
            super.continueButtonPressed(sender)
        case .fault:
            navigateToReplacePod()
        default:
            break
        }

    }

    override func cancelButtonPressed(_ sender: Any) {
//        switch pumpManager.podCommState {
//        case .noPod:
//            super.cancelButtonPressed(sender)
//        default:
            let confirmVC = UIAlertController(pumpDeletionHandler: {
                self.navigateToReplacePod()
            })
            self.present(confirmVC, animated: true) {}
//        }
    }

    // MARK: -

    func pair() {
        self.continueState = .pairing

        var timeoutHandler: DispatchWorkItem?

        pumpManager.startPodActivation(lowReservoirAlert: try! LowReservoirAlert(reservoirVolumeBelow: 1000),
                                                 podExpirationAlert: try! PodExpirationAlert(intervalBeforeExpiration: 4 * 60 * 60))
        { (activationStatus) in
            switch(activationStatus) {
            case .error(let error):
                timeoutHandler?.cancel()
                self.lastError = error
            case .event(let event):
                switch(event) {
                case .podStatus(let status):
                    print("Pod status: \(status)")
                case .primingPod:
                    let finishTime = TimeInterval(seconds: 35)
                    self.continueState = .priming(finishTime: finishTime)
                    timeoutHandler = DispatchWorkItem {
                        self.lastError = PodCommError.failToConnect
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + finishTime + TimeInterval(seconds: 10), execute: timeoutHandler!)
                case .step1Completed:
                    self.continueState = .ready
                default:
                    print("Ignoring event: \(event)")
                }
            }
        }
    }
}

private extension SetupButton {
    func setPairTitle() {
        setTitle(LocalizedString("Pair", comment: "Button title to pair with pod during setup"), for: .normal)
    }

    func setDeactivateTitle() {
        setTitle(LocalizedString("Deactivate", comment: "Button title to deactivate pod because of fault during setup"), for: .normal)
    }
}

private extension UIAlertController {
    convenience init(pumpDeletionHandler handler: @escaping () -> Void) {
        self.init(
            title: nil,
            message: LocalizedString("Are you sure you want to shutdown this pod?", comment: "Confirmation message for shutting down a pod"),
            preferredStyle: .actionSheet
        )

        addAction(UIAlertAction(
            title: LocalizedString("Deactivate Pod", comment: "Button title to deactivate pod"),
            style: .destructive,
            handler: { (_) in
                handler()
        }
        ))

        let exit = LocalizedString("Continue", comment: "The title of the continue action in an action sheet")
        addAction(UIAlertAction(title: exit, style: .default, handler: nil))
    }
}
