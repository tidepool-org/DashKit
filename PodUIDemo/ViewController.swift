//
//  ViewController.swift
//  OmnipodPluginHost
//
//  Created by Pete Schwamb on 3/2/21.
//  Copyright © 2021 Tidepool. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI
import DashKit
import DashKitUI
import PodSDK

class ViewController: UIViewController {
    
    var settingsViewController: UIViewController?
    var pumpManager: DashPumpManager?
    
    let palette = LoopUIColorPalette(
        guidanceColors: GuidanceColors(acceptable: .green, warning: .yellow, critical: .red),
        carbTintColor: .green,
        glucoseTintColor: .blue,
        insulinTintColor: .orange,
        chartColorPalette: ChartColorPalette(axisLine: .label, axisLabel: .label, grid: .secondaryLabel, glucoseTint: .blue, insulinTint: .orange))
    
    let basalSchedule = BasalRateSchedule(dailyItems: [RepeatingScheduleValue(startTime: 0, value: 1.0)])!


    override func viewDidLoad() {
        super.viewDidLoad()

        let button = UIButton()
        button.backgroundColor = .systemFill
        button.setTitle("First Time Flow", for: .normal)
        button.addTarget(self, action: #selector(firstTimeFlow), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(button)
        NSLayoutConstraint.activate(
            [
                NSLayoutConstraint(item: button, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 50.0),
                NSLayoutConstraint(item: button, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 200.0),
                NSLayoutConstraint(item: button, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: button, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1.0, constant: 100.0),
            ]
        )

        let button2 = UIButton()
        button2.backgroundColor = .systemFill
        button2.setTitle("Settings", for: .normal)
        button2.addTarget(self, action: #selector(settings), for: .touchUpInside)
        button2.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(button2)
        NSLayoutConstraint.activate(
            [
                NSLayoutConstraint(item: button2, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 50.0),
                NSLayoutConstraint(item: button2, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 200.0),
                NSLayoutConstraint(item: button2, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: button2, attribute: .top, relatedBy: .equal, toItem: button, attribute: .bottom, multiplier: 1.0, constant: 20.0)
            ]
        )
        
        view.setNeedsUpdateConstraints()
    }
    
    @objc func firstTimeFlow(sender: UIButton!) {
        let settings = PumpManagerSetupSettings(maxBasalRateUnitsPerHour: 3, maxBolusUnits: 3, basalSchedule: basalSchedule)
        let uiResult = MockPodPumpManager.setupViewController(initialSettings: settings, bluetoothProvider: self, colorPalette: palette)
        switch uiResult {
        case .createdAndOnboarded:
            return
        case .userInteractionRequired(var settingsViewController):
            self.settingsViewController = settingsViewController
            settingsViewController.completionDelegate = self
            settingsViewController.pumpManagerCreateDelegate = self
            present(settingsViewController, animated: true)
        }
    }
    
    @objc func settings(sender: UIButton!) {
        createPumpManagerIfNeeded()
        
        if let pumpManager = pumpManager {
            var vc = pumpManager.settingsViewController(bluetoothProvider: self, colorPalette: palette)
            vc.completionDelegate = self
            present(vc, animated: true)
        }
    }
    
    private func createPumpManagerIfNeeded() {
        let activationDate = Date()-TimeInterval(24 * 60 * 60)
        let podCommState = PodCommState.active
        if pumpManager == nil {
            let podStatus = MockPodStatus(
                activationDate: activationDate,
                podState: .basalProgramRunning,
                programStatus: .basalRunning,
                activeAlerts: [],
                bolusUnitsRemaining: 0,
                initialInsulinAmount: 200,
                insulinDelivered: 100,
                basalProgram: try! BasalProgram(basalSegments: [BasalSegment(startTime: 0, endTime: 48, basalRate: 100)]),
                podCommState: podCommState)
            var state = DashPumpManagerState(
                basalRateSchedule: basalSchedule,
                maximumTempBasalRate: 3,
                lastPodCommState: podCommState)!
            state.podActivatedAt = activationDate
            state.scheduledExpirationReminderOffset = TimeInterval(4 * 60 * 60)
            state.reservoirLevel = .aboveThreshold
            state.podAttachmentConfirmed = true
            pumpManager = MockPodPumpManager(podStatus: podStatus, state: state)
            pumpManager?.pumpManagerDelegate = self
        }
    }
}

extension ViewController: PumpManagerDelegate {
    func pumpManagerBLEHeartbeatDidFire(_ pumpManager: PumpManager) {
    }
    
    func pumpManagerMustProvideBLEHeartbeat(_ pumpManager: PumpManager) -> Bool {
        return false
    }
    
    func pumpManagerWillDeactivate(_ pumpManager: PumpManager) {
    }
    
    func pumpManager(_ pumpManager: PumpManager, didUpdatePumpRecordsBasalProfileStartEvents pumpRecordsBasalProfileStartEvents: Bool) {
    }
    
    func pumpManager(_ pumpManager: PumpManager, didError error: PumpManagerError) {
    }
    
    func pumpManager(_ pumpManager: PumpManager, hasNewPumpEvents events: [NewPumpEvent], lastReconciliation: Date?, completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
    
    func pumpManager(_ pumpManager: PumpManager, didReadReservoirValue units: Double, at date: Date, completion: @escaping (Result<(newValue: ReservoirValue, lastValue: ReservoirValue?, areStoredValuesContinuous: Bool), Error>) -> Void) {
    }
    
    func pumpManager(_ pumpManager: PumpManager, didAdjustPumpClockBy adjustment: TimeInterval) {
    }
    
    func pumpManagerDidUpdateState(_ pumpManager: PumpManager) {
    }
    
    func pumpManagerRecommendsLoop(_ pumpManager: PumpManager) {
    }
    
    func startDateToFilterNewPumpEvents(for manager: PumpManager) -> Date {
        return Date()
    }
    
    func scheduleNotification(for manager: DeviceManager, identifier: String, content: UNNotificationContent, trigger: UNNotificationTrigger?) {
    }
    
    func clearNotification(for manager: DeviceManager, identifier: String) {
    }
    
    func removeNotificationRequests(for manager: DeviceManager, identifiers: [String]) {
    }
    
    func deviceManager(_ manager: DeviceManager, logEventForDeviceIdentifier deviceIdentifier: String?, type: DeviceLogEntryType, message: String, completion: ((Error?) -> Void)?) {
    }
    
    func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus) {
    }
    
    func issueAlert(_ alert: Alert) {
    }
    
    func retractAlert(identifier: Alert.Identifier) {
    }
    
    
}

extension ViewController: PumpManagerCreateDelegate {
    func pumpManagerCreateNotifying(didCreatePumpManager pumpManager: PumpManagerUI) {
        if let pumpManager = pumpManager as? DashPumpManager {
            self.pumpManager = pumpManager
        }
    }
}

extension ViewController: CompletionDelegate {
    func completionNotifyingDidComplete(_ object: CompletionNotifying) {
        dismiss(animated: true)
    }
}

extension ViewController: BluetoothProvider {
    var bluetoothAuthorization: BluetoothAuthorization {
        return .authorized
    }
    
    var bluetoothState: BluetoothState {
        return .poweredOn
    }
    
    func authorizeBluetooth(_ completion: @escaping (BluetoothAuthorization) -> Void) {
        completion(.authorized)
    }
    
    func addBluetoothObserver(_ observer: BluetoothObserver, queue: DispatchQueue) {
    }
    
    func removeBluetoothObserver(_ observer: BluetoothObserver) {
    }
}
