//
//  ExpirationReminderDateTableViewCell.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 5/16/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import LoopKitUI

public class ExpirationReminderDateTableViewCell: DatePickerTableViewCell {

    public weak var delegate: DatePickerTableViewCellDelegate?

    @IBOutlet public weak var titleLabel: UILabel!

    @IBOutlet public weak var dateLabel: UILabel!

    var maximumDate: Date? {
        set {
            datePicker.maximumDate = newValue
        }
        get {
            return datePicker.maximumDate
        }
    }

    var minimumDate: Date? {
        set {
            datePicker.minimumDate = newValue
        }
        get {
            return datePicker.minimumDate
        }
    }

    private lazy var formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .medium
        formatter.doesRelativeDateFormatting = true

        return formatter
    }()

    public override func updateDateLabel() {
        dateLabel.text = formatter.string(from: date)
    }

    public override func dateChanged(_ sender: UIDatePicker) {
        super.dateChanged(sender)

        delegate?.datePickerTableViewCellDidUpdateDate(self)
    }
}

extension ExpirationReminderDateTableViewCell: NibLoadable { }
