//
//  UIViewControllerExtension.swift
//  SampleApp
//
//  Copyright © 2019 Insulet. All rights reserved.
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
        let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK button in a dialog"),
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
        let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK button in a dialog"),
                                     style: UIAlertAction.Style.default,
                                     handler: okButtonHandler)
        alertController.addAction(okAction)

        self.present(alertController, animated: true, completion: nil)
    }

    public func presentOkCancelDialog(title: String, message: String, okHandler: @escaping ((UIAlertAction) -> (Swift.Void)), cancelHandler: ((UIAlertAction) -> (Swift.Void))?) {
        let alertController = UIAlertController(title: title, message: message,
                                                preferredStyle: UIAlertController.Style.alert)
        let okAction = UIAlertAction(title: NSLocalizedString("Try again", comment: "Try again button in a dialog"),
                                     style: UIAlertAction.Style.default,
                                     handler: okHandler)
        alertController.addAction(okAction)
        let cancelAction = UIAlertAction(title: NSLocalizedString("Deactivate Pod", comment: "Deactivate Pod button in a dialog"),
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



