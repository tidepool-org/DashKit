//
//  RegistrationViewController.swift
//  SampleApp
//
//  Copyright © 2019 Insulet. All rights reserved.
//

import Foundation
import UIKit
import PodSDK

public enum SplashScreenConfiguration {
    case phoneRegistration, phoneValidation
}

class RegistrationViewController: UIViewController {

    @IBOutlet weak var phoneRegistration: UIButton!
    @IBOutlet weak var userDataLabel: UILabel!
    @IBOutlet weak var verificationCode: UITextField! {
        didSet {
            verificationCode?.addDoneToolbar(onDone: (target: self, action: #selector(doneButtonTapped)))
        }
    }

    @objc func doneButtonTapped() {
        verificationCode.resignFirstResponder()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        phoneRegistration.layer.cornerRadius = 10
        configureLayout(.phoneRegistration)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @IBAction func phoneRegistration(_ sender: UIButton) {
        guard !RegistrationManager.shared.isRegistered() else {
            presentOkDialog(title: "Error", message: "Phone already registered.")
            return
        }

        switch(sender.tag) {
        case 0:
            guard let phoneNumber = verificationCode.text else {
                presentOkDialog(title: "Error", message: "Enter phone number")
                return
            }

            RegistrationManager.shared.startRegistration(phoneNumber: phoneNumber) { (status) in
                switch(status) {
                case .registered, .alreadyRegistered:
                    self.presentOkDialog(title: "Error", message: "Phone already registered.")

                case .smsSent:
                    self.verificationCode.text = nil
                    self.presentOkDialog(title: "Success", message: "SMS sent")
                    self.configureLayout(.phoneValidation)
                    sender.tag = 1

                default:
                    self.presentOkDialog(title: "Error", message: "Phone registration error \(status)")
                }
            }

        case 1:
            guard let verificationCode = verificationCode.text else {
                presentOkDialog(title: "Error", message: "Enter verifiation code")
                return
            }
            RegistrationManager.shared.finishRegistration(verificationCode: verificationCode) { (status) in
                switch(status) {
                case .alreadyRegistered:
                    self.presentOkDialog(title: "Error", message: "Phone already registered.")

                case .registered:
                    self.presentOkDialog(title: "",
                                         message: "Validation completed",
                                         okButtonHandler: {_ in
                                            self.performSegue(withIdentifier: "Continue", sender: self)
                    })

                default:
                    self.presentOkDialog(title: "Error", message: "Phone registration error \(status)")

                }
            }

        default:
            break
        }
    }

    public func configureLayout(_ configuration: SplashScreenConfiguration) {
        guard isViewLoaded else { return }
        switch (configuration) {
        case .phoneRegistration:
            userDataLabel.text = "Enter the phone number to register "
        case .phoneValidation:
            phoneRegistration.setTitle("Validate", for: .normal)
            userDataLabel.text = "Enter the code"
            verificationCode.placeholder = "Ex: 123456"
        }
    }

}
