//
//  Pod.swift
//  DashKit
//
//  Created by Pete Schwamb on 4/18/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation

public struct Pod {
    // Volume of insulin in one motor pulse
    public static let pulseSize: Double = 0.05

    // Number of pulses required to delivery one unit of insulin
    public static let pulsesPerUnit: Double = 1/pulseSize

    // Units per second
    public static let bolusDeliveryRate: Double = 0.025

    // Maximum reservoir level reading
    public static let maximumReservoirReading: Double = 50

    // Reservoir Capacity
    public static let reservoirCapacity: Double = 200

    // Supported basal rates
    public static let supportedBasalRates: [Double] = (1...600).map { Double($0) / Double(pulsesPerUnit) }

    // Maximum number of basal schedule entries supported
    public static let maximumBasalScheduleEntryCount: Int = 24

    // Minimum duration of a single basal schedule entry
    public static let minimumBasalScheduleEntryDuration = TimeInterval.minutes(30)

    // Time from pod activation until expiration
    public static let lifetime = TimeInterval(hours: 72)

    // Time from expiration until pod fault
    public static let expirationWindow = TimeInterval(hours: 8)

    // PodSDK insulin values are U * 100
    public static let podSDKInsulinMultiplier: Double = 100
    
    // Estimated time for priming to complete; SDK will send back an event when priming completes,
    // But this lets us provide an estimate to the user.
    public static let estimatedPrimingDuration = TimeInterval(35)
    
    // Estimated time for cannula insertion; SDK will send back an event that actually marks the end,
    // but this lets us provide an estimate to the user
    public static let estimatedCannulaInsertionDuration = TimeInterval(10)
    
    // Default low reservoir alert limit in Units
    public static let defaultLowReservoirReminder: Double = 10
    
    // Default expiration reminder offset
    public static let defaultExpirationReminderOffset = TimeInterval(hours: 4)
    
    // Support phone number (TODO: get from SDK?)
    public static let supportPhoneNumber: String = "1-800-591-3455"
}
