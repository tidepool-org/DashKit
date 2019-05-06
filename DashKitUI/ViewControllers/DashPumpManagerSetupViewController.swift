//
//  DashPumpManagerSetupViewController.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 4/19/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import LoopKit
import LoopKitUI

public class DashPumpManagerSetupViewController: UINavigationController, PumpManagerSetupViewController, UINavigationControllerDelegate, CompletionNotifying {
    public var setupDelegate: PumpManagerSetupViewControllerDelegate?

    public var maxBasalRateUnitsPerHour: Double?

    public var maxBolusUnits: Double?

    public var basalSchedule: BasalRateSchedule?

    public var completionDelegate: CompletionDelegate?

    class func instantiateFromStoryboard() -> DashPumpManagerSetupViewController {
        return UIStoryboard(name: "DashPumpManager", bundle: Bundle(for: DashPumpManagerSetupViewController.self)).instantiateInitialViewController() as! DashPumpManagerSetupViewController
    }
}
