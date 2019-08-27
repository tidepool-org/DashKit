//
//  DashKitPlugin.swift
//  DashKit
//
//  Created by Pete Schwamb on 7/23/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import LoopKitUI
import DashKit
import DashKitUI
import os.log

class DashKitPlugin: NSObject, LoopUIPlugin {
    
    private let log = OSLog(category: "DashKitPlugin")

    public var pumpManagerType: PumpManagerUI.Type? {
        return DashPumpManager.self
    }

    public var cgmManagerType: CGMManagerUI.Type? {
        return nil
    }

    override init() {
        super.init()
        log.default("DashKitPlugin Instantiated")
    }
}
