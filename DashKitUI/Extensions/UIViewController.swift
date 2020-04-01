//
//  UIViewControllerExtension.swift
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

import UIKit
var vSpinner : UIView?

extension UITextField {
    func addDoneToolbar(onDone: (target: Any, action: Selector)? = nil) {
        let onDone = onDone ?? (target: self, action: #selector(doneButtonTapped))
        let toolbar: UIToolbar = UIToolbar()
        toolbar.barStyle = .default
        toolbar.items = [
            UIBarButtonItem(title: "Done", style: .done, target: onDone.target, action: onDone.action)
        ]
        toolbar.sizeToFit()
        self.inputAccessoryView = toolbar
    }
    @objc func doneButtonTapped() { self.resignFirstResponder() }
}

extension UIViewController {

    public func presentOkDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message,
                                                preferredStyle: UIAlertController.Style.alert)
        let okAction = UIAlertAction(title: LocalizedString("OK", comment: "OK button in a dialog"),
                                     style: UIAlertAction.Style.default) {
                                        (result : UIAlertAction) -> Void in
                                        // user tapped OK
        }
        alertController.addAction(okAction)

        self.present(alertController, animated: true, completion: nil)
    }

    public func presentOkDialog(title: String, message: String, okButtonHandler: @escaping ((UIAlertAction) -> (Swift.Void))) {
        let alertController = UIAlertController(title: title, message: message,
                                                preferredStyle: UIAlertController.Style.alert)
        let okAction = UIAlertAction(title: LocalizedString("OK", comment: "OK button in a dialog"),
                                     style: UIAlertAction.Style.default,
                                     handler: okButtonHandler)
        alertController.addAction(okAction)

        self.present(alertController, animated: true, completion: nil)
    }

    public func presentOkCancelDialog(title: String, message: String, okHandler: @escaping ((UIAlertAction) -> (Swift.Void)), cancelHandler: ((UIAlertAction) -> (Swift.Void))?) {
        let alertController = UIAlertController(title: title, message: message,
                                                preferredStyle: UIAlertController.Style.alert)
        let okAction = UIAlertAction(title: LocalizedString("Try again", comment: "Try again button in a dialog"),
                                     style: UIAlertAction.Style.default,
                                     handler: okHandler)
        alertController.addAction(okAction)
        let cancelAction = UIAlertAction(title: LocalizedString("Deactivate Pod", comment: "Deactivate Pod button in a dialog"),
                                         style: UIAlertAction.Style.default,
                                         handler: cancelHandler)
        alertController.addAction(cancelAction)

        self.present(alertController, animated: true, completion: nil)
    }

    func showSpinner(onView : UIView) {
        let spinnerView = UIView.init(frame: onView.bounds)
        spinnerView.backgroundColor = UIColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        let ai = UIActivityIndicatorView.init(style: .whiteLarge)
        ai.startAnimating()
        ai.center = spinnerView.center

        DispatchQueue.main.async {
            spinnerView.addSubview(ai)
            onView.addSubview(spinnerView)
        }
        vSpinner = spinnerView
    }

    func removeSpinner() {
        DispatchQueue.main.async {
            vSpinner?.removeFromSuperview()
            vSpinner = nil
        }
    }
}



