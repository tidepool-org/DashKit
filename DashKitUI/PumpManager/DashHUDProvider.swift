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
    
    private let bluetoothProvider: BluetoothProvider

    private let colorPalette: LoopUIColorPalette

    var visible: Bool = false {
        didSet {
            if oldValue != visible && visible {
                hudDidAppear()
            }
        }
    }

    public init(pumpManager: DashPumpManager, bluetoothProvider: BluetoothProvider, colorPalette: LoopUIColorPalette) {
        self.pumpManager = pumpManager
        self.bluetoothProvider = bluetoothProvider
        self.colorPalette = colorPalette
        super.init()
        self.pumpManager.addPodStatusObserver(self, queue: .main)
    }

    public func createHUDView() -> LevelHUDView? {
        reservoirView = OmnipodReservoirView.instantiate()
        updateReservoirView()

        return reservoirView
    }

    public func didTapOnHUDView(_ view: BaseHUDView, allowDebugFeatures: Bool) -> HUDTapAction? {
        let vc = pumpManager.settingsViewController(bluetoothProvider: bluetoothProvider, colorPalette: colorPalette, allowDebugFeatures: allowDebugFeatures)
        return HUDTapAction.presentViewController(vc)
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

        let reservoirAlertState: ReservoirAlertState
        
        if let reservoirLevel = pumpManager.reservoirLevel {
            switch reservoirLevel {
            case .aboveThreshold:
                reservoirAlertState = .ok
            case .valid(let amount):
                if amount > Pod.defaultLowReservoirReminder {
                    reservoirAlertState = .ok
                } else if amount <= 0 {
                    reservoirAlertState = .empty
                } else {
                    reservoirAlertState = .lowReservoir
                }
            }
        } else {
            reservoirAlertState = .ok
        }

        reservoirView.update(level: pumpManager.reservoirLevel, at: lastStatusDate, reservoirAlertState: reservoirAlertState)
    }
}

extension DashHUDProvider: PodStatusObserver {
    func didUpdatePodStatus() {
        updateReservoirView()
    }
}
