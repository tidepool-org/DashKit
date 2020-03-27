//
//  RegistrationViewController.swift
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
import os.log

public enum SplashScreenConfiguration {
    case phoneRegistration, phoneValidation
}

class RegistrationViewController: UIViewController {

    private let log = OSLog(category: "DashRegistrationViewController")

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
    }

    @IBAction func phoneRegistration(_ sender: UIButton) {

        guard !RegistrationManager.shared.isRegistered() else {
            log.default("phone is registered")
            presentOkDialog(title: "Error", message: "Phone already registered.")
            return
        }
        self.log.default("phone is not registered. starting registration")

        RegistrationManager.shared.startRegistration { (status) in
            self.log.default("startRegistration status: %{public}@", String(describing: status))
            switch status {
            case .registered, .alreadyRegistered:
                self.performSegue(withIdentifier: "Continue", sender: nil)
            default:
                self.presentOkDialog(title: "Error", message: "Phone registration error \(status)")
            }
        }
    }
}
