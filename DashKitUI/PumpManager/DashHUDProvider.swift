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
    
    private var refreshTimer: Timer?

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
        updateRefreshTimer()
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
            reservoirView!.update(level: reservoirLevel, at: lastStatusDate, reservoirAlertState: reservoirAlertStateFor(reservoirLevel))
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
            reservoirAlertState = DashHUDProvider.reservoirAlertStateFor(reservoirLevel)
        } else {
            reservoirAlertState = .ok
        }

        reservoirView.update(level: pumpManager.reservoirLevel, at: lastStatusDate, reservoirAlertState: reservoirAlertState)
    }

    private static func reservoirAlertStateFor(_ reservoirLevel: ReservoirLevel) -> ReservoirAlertState {
        switch reservoirLevel {
        case .aboveThreshold:
            return .ok
        case .valid(let amount):
            if amount > Pod.defaultLowReservoirReminder {
                return .ok
            } else if amount <= 0 {
                return .empty
            } else {
                return .lowReservoir
            }
        }
    }
    
    private func ensureRefreshTimerRunning() {
        guard refreshTimer == nil else {
            return
        }
        
        // 40 seconds is time for one unit
        refreshTimer = Timer(timeInterval: .seconds(40) , repeats: true) { _ in
            self.pumpManager.getPodStatus { _ in
                self.updateReservoirView()
            }
        }
        RunLoop.main.add(refreshTimer!, forMode: .default)
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func updateRefreshTimer() {
        if case .inProgress = pumpManager.status.bolusState, visible {
            ensureRefreshTimerRunning()
        } else {
            stopRefreshTimer()
        }
    }
}

extension DashHUDProvider: PodStatusObserver {
    func didUpdatePodStatus() {
        updateRefreshTimer()
        updateReservoirView()
    }
}
