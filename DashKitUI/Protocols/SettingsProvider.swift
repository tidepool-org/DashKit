//
//  SettingsProvider.swift
//  DashKit
//
//  Created by Pete Schwamb on 2/24/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import LoopKit

protocol SettingsProvider: class {
    var maxBolusUnits: Double? { get set }
    var basalSchedule: BasalRateSchedule? { get set }
    var maxBasalRateUnitsPerHour: Double? { get set }
}
