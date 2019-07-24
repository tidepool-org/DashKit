//
//  DashKitPlugin.swift
//  DashKit
//
//  Created by Pete Schwamb on 7/23/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import DashKit
import LoopKit

class DashKitPlugin: NSObject, LoopPlugin {
    public var pumpManagerType: PumpManager.Type? {
        return DashPumpManager.self
    }

    public var cgmManagerType: CGMManager.Type? {
        return nil
    }

    override init() {
        super.init()

        print("Loaded class")
    }
}
