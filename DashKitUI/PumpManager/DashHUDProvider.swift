//
//  DashHUDProvider.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 4/19/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import UIKit
import SwiftUI
import LoopKit
import LoopKitUI
import DashKit
import PodSDK

public enum ReservoirAlertState {
    case ok
    case lowReservoir
    case empty
}

internal class DashHUDProvider: NSObject, HUDProvider {
    var managerIdentifier: String {
        return pumpManager.managerIdentifier
    }

    private let pumpManager: DashPumpManager

    private var reservoirView: OmnipodReservoirView?
    
    private let insulinTintColor: Color
    
    private let guidanceColors: GuidanceColors

    var visible: Bool = false {
        didSet {
            if oldValue != visible && visible {
                hudDidAppear()
            }
        }
    }

    public init(pumpManager: DashPumpManager, insulinTintColor: Color, guidanceColors: GuidanceColors) {
        self.pumpManager = pumpManager
        self.insulinTintColor = insulinTintColor
        self.guidanceColors = guidanceColors
        super.init()
        self.pumpManager.addPodStatusObserver(self, queue: .main)
    }

    public func createHUDView() -> LevelHUDView? {
        reservoirView = OmnipodReservoirView.instantiate()
        updateReservoirView()

        return reservoirView
    }

    public func didTapOnHUDView(_ view: BaseHUDView) -> HUDTapAction? {
        return HUDTapAction.presentViewController(pumpManager.settingsViewController(insulinTintColor: insulinTintColor, guidanceColors: guidanceColors))
    }

    func hudDidAppear() {
        updateReservoirView()
        pumpManager.getPodStatus { (_) in }
    }
    
    public var hudViewRawState: HUDProvider.HUDViewRawState {
        var rawValue: HUDProvider.HUDViewRawState = [:]
        
        rawValue["lastStatusDate"] = pumpManager.lastStatusDate

        if let reservoirLevel = pumpManager.reservoirLevel {
            rawValue["reservoirLevel"] = reservoirLevel.rawValue
        }

        return rawValue
    }

    public static func createHUDView(rawValue: HUDProvider.HUDViewRawState) -> LevelHUDView? {
        guard let rawReservoirLevel = rawValue["reservoirLevel"] as? ReservoirLevel.RawValue else {
            return nil
        }

        let reservoirView: OmnipodReservoirView?

        let reservoirLevel = ReservoirLevel(rawValue: rawReservoirLevel)

        if let lastStatusDate = rawValue["lastStatusDate"] as? Date {
            reservoirView = OmnipodReservoirView.instantiate()
            reservoirView!.update(level: reservoirLevel, at: lastStatusDate, reservoirAlertState: .ok)
        } else {
            reservoirView = nil
        }

        return reservoirView
    }

    private func updateReservoirView() {
        guard let reservoirView = reservoirView,
            let lastStatusDate = pumpManager.lastStatusDate else
        {
            return
        }

        let reservoirAlertState: ReservoirAlertState = pumpManager.isReservoirLow ? .lowReservoir : .ok

        reservoirView.update(level: pumpManager.reservoirLevel, at: lastStatusDate, reservoirAlertState: reservoirAlertState)
    }
}

extension DashHUDProvider: PodStatusObserver {
    func didUpdatePodStatus() {
        updateReservoirView()
    }
}
