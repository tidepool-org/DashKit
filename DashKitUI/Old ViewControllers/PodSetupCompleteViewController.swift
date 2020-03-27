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
    
    class func instantiateFromStoryboard(_ pumpManager: DashPumpManager, navigator: DashUINavigator) -> PodSetupCompleteViewController {
        let vc = UIStoryboard(name: "DashPumpManager", bundle: Bundle(for: PodSetupCompleteViewController.self)).instantiateViewController(withIdentifier: "PodSetupCompleteViewController") as! PodSetupCompleteViewController
        vc.pumpManager = pumpManager
        vc.navigator = navigator
        return vc
    }
    
    weak var navigator: DashUINavigator?

    @IBOutlet weak var expirationReminderDateCell: ExpirationReminderDateTableViewCell!

    var pumpManager: DashPumpManager!
    
    var completion: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.padFooterToBottom = false

        self.navigationItem.hidesBackButton = true
        self.navigationItem.rightBarButtonItem = nil

        expirationReminderDateCell.datePicker.datePickerMode = .dateAndTime
        expirationReminderDateCell.titleLabel.text = LocalizedString("Expiration Reminder", comment: "The title of the cell showing the pod expiration reminder date")
        expirationReminderDateCell.datePicker.minuteInterval = 1
        expirationReminderDateCell.delegate = self
        
       if let expirationDate = pumpManager.podExpiresAt {
           expirationReminderDateCell.date = expirationDate.addingTimeInterval(TimeInterval(hours: -2))
           expirationReminderDateCell.datePicker.maximumDate = expirationDate.addingTimeInterval(TimeInterval(hours: -2))
           expirationReminderDateCell.datePicker.minimumDate = expirationDate.addingTimeInterval(TimeInterval(hours: -8))
       }
    }

    override func continueButtonPressed(_ sender: Any) {
        completion?()
    }

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
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
