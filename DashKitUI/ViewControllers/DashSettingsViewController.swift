//
//  DashSettingsViewController.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 4/19/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import DashKit
import LoopKit

class DashSettingsViewController: UITableViewController {

    let pumpManager: DashPumpManager

    init(pumpManager: DashPumpManager) {
        self.pumpManager = pumpManager

        super.init(style: .grouped)

        pumpManager.addStatusObserver(self, queue: .main)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

extension DashSettingsViewController: PumpManagerStatusObserver {
    func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus) {
    }
}
