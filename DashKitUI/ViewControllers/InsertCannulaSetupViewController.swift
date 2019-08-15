//
//  InsertCannulaSetupViewController.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 5/16/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI
import DashKit
import PodSDK
import SwiftGif


class InsertCannulaSetupViewController: SetupTableViewController {

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

    private var cancelErrorCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        continueState = .initial

        if let dataAsset = NSDataAsset(name: "Prep Pod", bundle: Bundle(for: PairPodSetupViewController.self)) {
            let image = UIImage.gif(data: dataAsset.data)
            imageView.image = image
        }
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if case .startingInsertion = continueState {
            return
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - Navigation

    private enum State {
        case initial
        case startingInsertion
        case inserting(finishTime: CFTimeInterval)
        case fault
        case ready
    }

    private var continueState: State = .initial {
        didSet {
            switch continueState {
            case .initial:
                activityIndicator.state = .hidden
                footerView.primaryButton.isEnabled = true
                footerView.primaryButton.setConnectTitle()
            case .startingInsertion:
                activityIndicator.state = .indeterminantProgress
                footerView.primaryButton.isEnabled = false
                lastError = nil
            case .inserting(let finishTime):
                activityIndicator.state = .timedProgress(finishTime: CACurrentMediaTime() + finishTime)
                footerView.primaryButton.isEnabled = false
                lastError = nil
            case .fault:
                activityIndicator.state = .hidden
                footerView.primaryButton.isEnabled = true
                footerView.primaryButton.setDeactivateTitle()
            case .ready:
                activityIndicator.state = .completed
                footerView.primaryButton.isEnabled = true
                footerView.primaryButton.resetTitle()
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

            loadingText = errorText

            // If we have an error, update the continue state
            if let podCommsError = lastError as? PodCommError,
                case PodCommError.podIsInAlarm = podCommsError
            {
                continueState = .fault
            } else if lastError != nil {
                continueState = .initial
            }
        }
    }

    private func navigateToReplacePod() {
        performSegue(withIdentifier: "ReplacePod", sender: nil)
    }

    override func continueButtonPressed(_ sender: Any) {
        switch continueState {
        case .initial:
            continueState = .startingInsertion
            insertCannula()
        case .ready:
            super.continueButtonPressed(sender)
        case .fault:
            navigateToReplacePod()
        default:
            break
        }
    }

    override func cancelButtonPressed(_ sender: Any) {
        let confirmVC = UIAlertController(pumpDeletionHandler: {
            self.navigateToReplacePod()
        })
        present(confirmVC, animated: true) {}
    }

    func insertCannula() {

        let autoOffAlert = try! AutoOffAlert.init(enable: true, interval: 4 * 60 * 60)
        continueState = .startingInsertion
        var expectingAnotherEvent = false
        pumpManager.finishPodActivation(autoOffAlert: autoOffAlert) { (activationStatus) in
            switch(activationStatus) {
            case .error(let error):
                expectingAnotherEvent = false
                self.lastError = error
            case .event(let event):
                print("event: \(event)")
                switch(event) {
                case .insertingCannula:
                    expectingAnotherEvent = true
                    let finishTime = TimeInterval(seconds: 10)
                    self.continueState = .inserting(finishTime: finishTime)
                    DispatchQueue.main.asyncAfter(deadline: .now() + finishTime + TimeInterval(seconds: 5)) {
                        if expectingAnotherEvent {
                            self.lastError = PodCommError.failToConnect
                        }
                    }
                case .step2Completed:
                    expectingAnotherEvent = false
                    self.continueState = .ready
                default:
                    break
                }
            }
        }
    }
}

private extension SetupButton {
    func setConnectTitle() {
        setTitle(LocalizedString("Insert Cannula", comment: "Button title to insert cannula during setup"), for: .normal)
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

