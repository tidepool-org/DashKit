//
//  PodSetupCompleteViewController.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 5/16/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import UIKit
import LoopKitUI
import DashKit
import PodSDK

class PodSetupCompleteViewController: SetupTableViewController {

    @IBOutlet weak var expirationReminderDateCell: ExpirationReminderDateTableViewCell!

    var pumpManager: DashPumpManager! {
        didSet {
            if let expirationDate = pumpManager.podExpiresAt {
                expirationReminderDateCell.date = expirationDate.addingTimeInterval(TimeInterval(hours: -2))
                expirationReminderDateCell.datePicker.maximumDate = expirationDate.addingTimeInterval(TimeInterval(hours: -2))
                expirationReminderDateCell.datePicker.minimumDate = expirationDate.addingTimeInterval(TimeInterval(hours: -8))
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.padFooterToBottom = false

        self.navigationItem.hidesBackButton = true
        self.navigationItem.rightBarButtonItem = nil

        expirationReminderDateCell.datePicker.datePickerMode = .dateAndTime
        expirationReminderDateCell.titleLabel.text = LocalizedString("Expiration Reminder", comment: "The title of the cell showing the pod expiration reminder date")
        expirationReminderDateCell.datePicker.minuteInterval = 1
        expirationReminderDateCell.delegate = self
    }

    override func continueButtonPressed(_ sender: Any) {
        if let setupVC = navigationController as? DashPumpManagerSetupViewController {
            setupVC.finishedSetup()
        }
        if let replaceVC = navigationController as? PodReplacementNavigationController {
            replaceVC.completeSetup()
        }
        if let settingsVC = navigationController as? SettingsNavigationViewController {
            settingsVC.notifyComplete()
        }
    }

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        print("willSelectRowAt")
        tableView.beginUpdates()
        return indexPath
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.endUpdates()
    }

}

extension PodSetupCompleteViewController: DatePickerTableViewCellDelegate {
    func datePickerTableViewCellDidUpdateDate(_ cell: DatePickerTableViewCell) {
        // TODO
        //pumpManager.expirationReminderDate = cell.date
    }
}
