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
import PodSDK

public enum ReservoirAlertState {
    case ok
    case lowReservoir
    case empty
}

internal class DashHUDProvider: NSObject, HUDProvider {
    var managerIdentifier: String {
        return DashPumpManager.managerIdentifier
    }

    private let pumpManager: DashPumpManager

    private var reservoirView: OmnipodReservoirView?
    
    private var podLifeView: PodLifeHUDView?

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
        super.init()
        self.pumpManager.addPodStatusObserver(self, queue: .main)
    }

    public func createHUDViews() -> [BaseHUDView] {
        reservoirView = OmnipodReservoirView.instantiate()
        updateReservoirView()

        podLifeView = PodLifeHUDView.instantiate()

        if visible {
            updatePodLifeView()
            updateFaultDisplay()
        }

        return [reservoirView, podLifeView].compactMap { $0 }
    }

    public func didTapOnHUDView(_ view: BaseHUDView) -> HUDTapAction? {
        return HUDTapAction.presentViewController(pumpManager.settingsViewController())
    }

    func hudDidAppear() {
        updatePodLifeView()
        updateReservoirView()
        updateFaultDisplay()
        pumpManager.getPodStatus { (_) in }
    }
    public var hudViewsRawState: HUDProvider.HUDViewsRawState {
        var rawValue: HUDProvider.HUDViewsRawState = [:]

        rawValue["podActivatedAt"] = pumpManager.podActivatedAt
        rawValue["lastStatusDate"] = pumpManager.lastStatusDate

        if let reservoirLevel = pumpManager.reservoirLevel {
            rawValue["reservoirLevel"] = reservoirLevel.rawValue
        }

        return rawValue
    }

    public static func createHUDViews(rawValue: HUDProvider.HUDViewsRawState) -> [BaseHUDView] {
        guard let podActivatedAt = rawValue["podActivatedAt"] as? Date,
            let lifetime = rawValue["lifetime"] as? Double,
            let rawReservoirLevel = rawValue["reservoirLevel"] as? ReservoirLevel.RawValue else
        {
            return []
        }

        let reservoirView: OmnipodReservoirView?

        let reservoirLevel = ReservoirLevel(rawValue: rawReservoirLevel)

        if let validTime = rawValue["validTime"] as? Date
        {
            reservoirView = OmnipodReservoirView.instantiate()
            reservoirView!.update(level: reservoirLevel, at: validTime, reservoirAlertState: .ok)
        } else {
            reservoirView = nil
        }

        let podLifeHUDView = PodLifeHUDView.instantiate()
        podLifeHUDView.setPodLifeCycle(startTime: podActivatedAt, lifetime: lifetime)

        return [reservoirView, podLifeHUDView].compactMap({ $0 })
    }

    private func updateReservoirView() {
        guard let reservoirView = reservoirView,
            let lastStatusDate = pumpManager.lastStatusDate else
        {
            return
        }

        let reservoirLevel = pumpManager.reservoirLevel

        var reservoirAlertState: ReservoirAlertState = .ok

        if pumpManager.isReservoirLow {
            reservoirAlertState = .lowReservoir
        }

        reservoirView.update(level: reservoirLevel, at: lastStatusDate, reservoirAlertState: reservoirAlertState)
    }

    private func updateFaultDisplay() {
        guard let podLifeView = podLifeView else {
            return
        }

        if pumpManager.isPodAlarming {
            podLifeView.alertState = .fault
        } else {
            podLifeView.alertState = .none
        }
    }

    private func updatePodLifeView() {
        guard let podLifeView = podLifeView else {
            return
        }

        let lifetime = Pod.lifetime

        podLifeView.setPodLifeCycle(startTime: pumpManager.podActivatedAt, lifetime: lifetime)
    }
}

extension DashHUDProvider: PodStatusObserver {
    func didUpdatePodStatus() {
        updatePodLifeView()
        updateReservoirView()
        updateFaultDisplay()
    }
}
