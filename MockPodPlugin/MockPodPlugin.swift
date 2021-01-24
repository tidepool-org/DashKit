//
//  MockPodPlugin.swift
//  MockPodPlugin
//
//  Created by Pete Schwamb on 12/11/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import os.log
import LoopKitUI
import DashKit
import DashKitUI

class MockPodPlugin: NSObject, PumpManagerUIPlugin {
    private let log = OSLog(category: "MockPodPlugin")

    public var pumpManagerType: PumpManagerUI.Type? {
        return MockPodPumpManager.self
    }

    override init() {
        super.init()
        log.default("Instantiated")
    }
}
