//
//  DashHUDProvider.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 4/19/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI
import DashKit

internal class DashHUDProvider: NSObject, HUDProvider {
    var managerIdentifier: String {
        return DashPumpManager.managerIdentifier
    }

    private let pumpManager: DashPumpManager

//    private var reservoirView: OmnipodReservoirView?
//
//    private var podLifeView: PodLifeHUDView?

    var visible: Bool = false {
        didSet {
            if oldValue != visible && visible {
                hudDidAppear()
            }
        }
    }

    public init(pumpManager: DashPumpManager) {
        self.pumpManager = pumpManager
        //self.podState = pumpManager.state.podState
        super.init()
        //self.pumpManager.addPodStateObserver(self)
    }

    public func createHUDViews() -> [BaseHUDView] {
        return []
    }

    public func didTapOnHUDView(_ view: BaseHUDView) -> HUDTapAction? {
        return nil
    }

    func hudDidAppear() {
    }

    public var hudViewsRawState: HUDProvider.HUDViewsRawState {
        return [:]
    }

    public static func createHUDViews(rawValue: HUDProvider.HUDViewsRawState) -> [BaseHUDView] {
        return []
    }
}
