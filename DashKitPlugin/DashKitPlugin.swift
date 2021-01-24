//
//  DashKitPlugin.swift
//  DashKit
//
//  Created by Pete Schwamb on 7/23/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import os.log
import LoopKitUI
import DashKit
import DashKitUI

class DashKitPlugin: NSObject, PumpManagerUIPlugin {
    private let log = OSLog(category: "DashKitPlugin")

    public var pumpManagerType: PumpManagerUI.Type? {
        return DashPumpManager.self
    }

    override init() {
        super.init()
        log.default("Instantiated")
    }
}
