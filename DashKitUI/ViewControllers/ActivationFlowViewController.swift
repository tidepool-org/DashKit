//
//  ActivationFlowViewController.swift
//  SampleApp
//
// Copyright (C) 2019, Insulet Corporation
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software
// and associated documentation files (the "Software"), to deal in the Software without restriction,
// including without limitation the rights to use, copy, modify, merge, publish, distribute,
// sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial
// portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
// NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation
import UIKit
import PodSDK
import DashKit

public enum ActivationConfiguration {
    case startActivation, finishActivation
}

class ActivationFlowViewController: UIViewController {

    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var centerPopUpConstraint: NSLayoutConstraint!
    @IBOutlet weak var eventLogTextView: UITextView!
    @IBOutlet var activationFlowView: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var activationButton: UIButton!

    var pumpManager: DashPumpManager?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureLayout(.startActivation)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        eventLogTextView.isEditable = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func deactivatePod(){
        if let pumpManager = pumpManager {
            self.showSpinner(onView: self.view)
            pumpManager.deactivatePod { (result) in
                switch(result) {
                case .failure(let pdmError):
                    self.presentOkDialog(title: "",
                                         message: "Deactivate Pod error: \(pdmError). Do you want to discard Pod?",
                        okButtonHandler: {_ in
                            self.discardPod()
                            self.removeSpinner()
                    })
                case .success(let status):
                    self.presentOkDialog(title: "",
                                         message: "Pod deactivated with \(String(describing: status.podState))",
                        okButtonHandler: {_ in
                            self.removeSpinner()
                    })
                }
            }
        }
    }

    @IBAction func startActivation(_ sender: UIButton) {
        showProgress()
        continueButton.isHidden = true
        switch(sender.tag) {
        case 0:
            PodCommManager.shared.startPodActivation(lowReservoirAlert: try! LowReservoirAlert(reservoirVolumeBelow: 1000),
                                                     podExpirationAlert: try! PodExpirationAlert(intervalBeforeExpiration: 4 * 60 * 60)) { (activationStatus) in
                                                        switch(activationStatus) {
                                                        case .error(let pdmError):
                                                            self.eventLogTextView.text = (self.eventLogTextView.text ?? "").appending("\nActivation Error: \(String(describing: pdmError.errorDescription))")
                                                            self.errorOnActivation(error: pdmError)

                                                        case .event(let event):
                                                            switch(event) {
                                                            case .podStatus(let status):
                                                                self.eventLogTextView.text = (self.eventLogTextView.text ?? "").appending("\nPod status: \(String(describing: status.podState))")

                                                            default:
                                                                self.eventLogTextView.text = (self.eventLogTextView.text ?? "").appending("\nEvent: \(event.description)")
                                                                if(event == .step1Completed) {
                                                                    self.continueButton.isHidden = false
                                                                    sender.tag = 1
                                                                }
                                                            }
                                                        }
            }

        case 1:
            if let pumpManager = pumpManager {
                let basalProgram = pumpManager.state.basalProgram
                let autoOffAlert = try! AutoOffAlert.init(enable: true, interval: 4 * 60 * 60)
                PodCommManager.shared.finishPodActivation(basalProgram: basalProgram, autoOffAlert: autoOffAlert) { (activationStatus) in
                    switch(activationStatus) {
                    case .error(let error):
                        self.eventLogTextView.text = (self.eventLogTextView.text ?? "").appending("\nActivation Error: \(error)")
                        self.errorOnActivation(error: error)

                    case .event(let event):
                        switch(event) {
                        case .podStatus(let status):
                            self.eventLogTextView.text = (self.eventLogTextView.text ?? "").appending("\nPod status: \(String(describing: status.podState))")

                        default:
                            self.eventLogTextView.text = (self.eventLogTextView.text ?? "").appending("\nEvent: \(event.description)")
                            if(event == .step2Completed) {
                                self.presentOkDialog(title: "",
                                                     message: "Pod Activation completed!",
                                                     okButtonHandler: {_ in
                                                        if let tabViewController = self.storyboard?.instantiateViewController(withIdentifier: "TabBarController") as? UITabBarController {
                                                            self.present(tabViewController, animated: true, completion: nil)
                                                        }
                                })
                            }
                        }
                    }
                }
            }

        default:
            break
        }
    }

    func discardPod() {
        PodCommManager.shared.discardPod { (result) in
            self.eventLogTextView.text = (self.eventLogTextView.text ?? "").appending("\nDiscarding Pod")
            switch(result) {
            case .failure(let pdmError):
                self.eventLogTextView.text = (self.eventLogTextView.text ?? "").appending("\nDiscard Pod Error: \(pdmError)")

            case .success(_):
                self.eventLogTextView.text = (self.eventLogTextView.text ?? "").appending("\nPod is discarded.")
                self.presentOkDialog(title: "",
                                     message: "Pod is discarded. Do you want to start activation again?",
                                     okButtonHandler: {_ in
                                        self.hideProgress()
                })
            }
        }
    }

    func errorOnActivation(error : PodCommError) {
        if(error == .messageSigningFailed) {
            presentOkDialog(title: "",
                            message: "Message signing failed error. Do you want to try again?",
                            okButtonHandler: {_ in
                                self.eventLogTextView.text = (self.eventLogTextView.text ?? "").appending("\nTrying again")
                                self.activationButton.sendActions(for: .touchUpInside)
            })
        } else {
            presentOkCancelDialog(title: "Activation Error",
                                  message: "Unable to activate Pod. Do you want to try again?",
                                  okHandler: {_ in  self.eventLogTextView.text = ""
                                    self.eventLogTextView.text = (self.eventLogTextView.text ?? "").appending("\nTrying again")
                                    self.activationButton.sendActions(for: .touchUpInside)
            },
                                  cancelHandler: {_ in self.eventLogTextView.text = ""
                                    self.deactivatePod()
                                    self.hideProgress()
                                    self.configureLayout(.startActivation)
            })
        }
    }

    @IBAction func continueButton(_ sender: Any) {
        hideProgress()
        configureLayout(.finishActivation)
    }

    public func configureLayout(_ configuration: ActivationConfiguration) {
        guard isViewLoaded else { return }
        switch (configuration) {
        case .finishActivation:
            activationButton.setTitle("Finish Activation", for: .normal)
            messageLabel.text = "Pod Activation Phase 2"

        case .startActivation:
            activationButton.setTitle("Start Activation", for: .normal)
            messageLabel.text = "Pod Activation Phase 1"
            break
        }
    }

    func hideProgress() {
        self.eventLogTextView.text = ""
        self.centerPopUpConstraint.constant = -420.0
    }

    func showProgress() {
        self.eventLogTextView.text = ""
        self.centerPopUpConstraint.constant = 0
    }
}
