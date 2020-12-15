//
//  MockPodPumpManager.swift
//  MockPodPlugin
//
//  Created by Pete Schwamb on 12/11/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import DashKit
import LoopKit

class MockPodPumpManager: DashPumpManager {

    public override var managerIdentifier: String {
        return "OmnipodDemo"
    }

    public required init(state: DashPumpManagerState, dateGenerator: @escaping () -> Date = Date.init) {
        
        let actualPodCommManager = MockPodCommManager.shared
        actualPodCommManager.update(for: state)
        
        super.init(state: state, podCommManager: actualPodCommManager, dateGenerator: dateGenerator)

        actualPodCommManager.dashPumpManager = self
    }
    
    public convenience required init?(rawState: PumpManager.RawStateValue) {
        guard let state = DashPumpManagerState(rawValue: rawState) else
        {
            return nil
        }
        
        self.init(state: state)
    }

}
