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

class DashKitPlugin: NSObject, LoopUIPlugin {
    public var pumpManagerType: PumpManagerUI.Type? {
        return DashPumpManager.self
    }

    public var cgmManagerType: CGMManagerUI.Type? {
        return nil
    }

    override init() {
        super.init()

        print("Loaded DashKitPlugin class")
    }
}
