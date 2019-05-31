//
//  InsulinStatusTableViewCell.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 5/29/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation

public class InsulinStatusTableViewCell: UITableViewCell {

    @IBOutlet public weak var insulinLabel: UILabel!

    @IBOutlet public weak var recencyLabel: UILabel!

}

extension InsulinStatusTableViewCell: NibLoadable { }
