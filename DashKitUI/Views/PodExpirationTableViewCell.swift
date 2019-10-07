//
//  PodExpirationTableViewCell.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 5/31/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation

public class PodExpirationTableViewCell: UITableViewCell {

    @IBOutlet public weak var dateLabel: UILabel!

    @IBOutlet public weak var timeLabel: UILabel!

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return formatter
    }()

    public var expirationDate: Date? {
        didSet {
            if let date = expirationDate {
                let calendar = Calendar.current
                var dayText: String? = nil
                if calendar.isDateInToday(date) {
                    dayText = LocalizedString("Today", comment: "Name for current day")
                } else if calendar.isDateInTomorrow(date) {
                    dayText = LocalizedString("Tomorrow", comment: "Name for day following this day")
                } else if calendar.isDateInYesterday(date) {
                    dayText = LocalizedString("Yesterday", comment: "Name for day preceeding this day")
                } else {
                    if let weekday = Calendar.current.dateComponents([.weekday], from: date).weekday {
                        dayText = dateFormatter.weekdaySymbols[weekday-1]
                    }
                }
                dateLabel.text = dayText
                timeLabel.text = dateFormatter.string(from: date)
            }
        }
    }
}
