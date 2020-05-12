//
//  PodSDKLoggingShim.swift
//  DashKit
//
//  Created by Pete Schwamb on 1/21/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import PodSDK
import LoopKit

protocol PodSDKLoggingShimDelegate: class {
    func podSDKLoggingShim(_ shim: PodSDKLoggingShim, didLogEventForDevice deviceIdentifier: String?, type: DeviceLogEntryType, message: String, completion: ((Error?) -> Void)?)
}

class PodSDKLoggingShim {
    
    private var target: PodCommManagerProtocol
    var deviceIdentifier: String?
    weak var loggingShimDelegate: PodSDKLoggingShimDelegate?
    

    init(target: PodCommManagerProtocol) {
        self.target = target
    }
    
    var delegate: PodCommManagerDelegate? {
        set {
            target.delegate = newValue
        }
        get {
            return target.delegate
        }
    }
    
    private func logSend(_ message: String, completion: ((Error?) -> Void)? = nil) {
        loggingShimDelegate?.podSDKLoggingShim(self, didLogEventForDevice: deviceIdentifier, type: .send, message: message, completion: completion)
    }
    
    private func logReceive(_ message: String, completion: ((Error?) -> Void)? = nil) {
        loggingShimDelegate?.podSDKLoggingShim(self, didLogEventForDevice: deviceIdentifier, type: .receive, message: message, completion: completion)
    }
}

extension PodSDKLoggingShim: PodCommManagerProtocol {
    func setup(withLaunchingOptions launchOptions: [AnyHashable : Any]?) {
        target.setup(withLaunchingOptions: launchOptions)
    }
    
    func setLogger(logger: LoggingProtocol) {
        target.setLogger(logger: logger)
    }
        
    func startPodActivation(lowReservoirAlert: LowReservoirAlert?, podExpirationAlert: PodExpirationAlert?, eventListener: @escaping (ActivationStatus<ActivationStep1Event>) -> ()) {
        logSend("startPodActivation(\(String(describing: lowReservoirAlert)), \(String(describing: podExpirationAlert)))")
        target.startPodActivation(lowReservoirAlert: lowReservoirAlert, podExpirationAlert: podExpirationAlert) { (event) in
            self.logReceive("startPodActivation event: \(event)")
            eventListener(event)
        }
    }
    
    func finishPodActivation(basalProgram: ProgramType, autoOffAlert: AutoOffAlert?, eventListener: @escaping (ActivationStatus<ActivationStep2Event>) -> ()) {
        logSend("finishPodActivation(\(basalProgram), \(String(describing: autoOffAlert)))")
        target.finishPodActivation(basalProgram: basalProgram, autoOffAlert: autoOffAlert) { (event) in
            self.logReceive("finishPodActivation event: \(event)")
            eventListener(event)
        }
    }
    
    func discardPod(completion: @escaping (PodCommResult<Bool>) -> ()) {
        logSend("discardPod()")
        target.discardPod { (result) in
            self.logReceive("discardPod result: \(result)")
            completion(result)
        }
    }
    
    func deactivatePod(completion: @escaping (PodCommResult<PartialPodStatus>) -> ()) {
        logSend("deactivatePod()")
        target.deactivatePod { (result) in
            self.logReceive("deactivatePod result: \(result)")
            completion(result)
        }
    }
    
    func getPodStatus(userInitiated: Bool, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        logSend("getPodStatus(\(userInitiated))")
        target.getPodStatus(userInitiated: userInitiated) { (result) in
            self.logReceive("getPodStatus result: \(result)")
            completion(result)
        }
    }
    
    func getAlertsDetails(completion: @escaping (PodCommResult<PodAlerts>) -> ()) {
        logSend("getAlertsDetails()")
        target.getAlertsDetails { (alerts) in
            self.logReceive("getAlertsDetails alerts: \(alerts)")
            completion(alerts)
        }
    }
    
    func playTestBeeps(completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        logSend("playTestBeeps()")
        target.playTestBeeps { (result) in
            self.logReceive("playTestBeeps result: \(result)")
            completion(result)
        }
    }
    
    func updateBeepOptions(bolusReminder: BeepOption, tempBasalReminder: BeepOption, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        logSend("updateBeepOptions(\(bolusReminder), \(tempBasalReminder))")
        target.updateBeepOptions(bolusReminder: bolusReminder, tempBasalReminder: tempBasalReminder) { (result) in
            self.logReceive("updateBeepOptions result: \(result)")
            completion(result)
        }
    }
    
    func sendProgram(programType: ProgramType, beepOption: BeepOption?, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        logSend("sendProgram(\(programType), \(String(describing: beepOption)))")
        target.sendProgram(programType: programType, beepOption: beepOption) { (result) in
            self.logReceive("sendProgram result: \(result)")
            completion(result)
        }
    }
    
    func stopProgram(programType: StopProgramType, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        logSend("stopProgram(\(programType))")
        target.stopProgram(programType: programType) { (result) in
            self.logReceive("stopProgram result: \(result)")
            completion(result)
        }
    }
    
    func updateAlertSetting(alertSetting: PodAlertSetting, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        logSend("updateAlertSetting(\(alertSetting))")
        target.updateAlertSetting(alertSetting: alertSetting) { (result) in
            self.logReceive("updateAlertSetting result: \(result)")
            completion(result)
        }
    }
    
    func silenceAlerts(alert: PodAlerts, completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        logSend("silenceAlerts(\(alert))")
        target.silenceAlerts(alert: alert) { (result) in
            self.logReceive("silenceAlerts result: \(result)")
            completion(result)
        }
    }
    
    func retryUnacknowledgedCommand(completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        logSend("retryUnacknowledgedCommand()")
        target.retryUnacknowledgedCommand { (status) in
            self.logReceive("retryUnacknowledgedCommand result: \(status)")
            completion(status)
        }
    }
    
    func queryAndClearUnacknowledgedCommand(completion: @escaping (PodCommResult<PendingRetryResult>) -> ()) {
        logSend("queryAndClearUnacknowledgedCommand()")
        target.queryAndClearUnacknowledgedCommand { (result) in
            self.logReceive("queryAndClearUnacknowledgedCommand result: \(result)")
            completion(result)
        }
    }
    
    func configPeriodicStatusCheck(interval: TimeInterval, completion: @escaping (PodCommResult<Bool>) -> ()) {
        logSend("configPeriodicStatusCheck(\(interval))")
        target.configPeriodicStatusCheck(interval: interval) { (result) in
            self.logReceive("configPeriodicStatusCheck result: \(result)")
            completion(result)
        }
    }
    
    func disablePeriodicStatusCheck(completion: @escaping (PodCommResult<Bool>) -> ()) {
        logSend("disablePeriodicStatusCheck()")
        target.disablePeriodicStatusCheck { (result) in
            self.logReceive("disablePeriodicStatusCheck result: \(result)")
            completion(result)
        }
    }
    
    func retrievePDMId() -> String? {
        return target.retrievePDMId()
    }
    
    var podVersionAbstracted: PodVersionProtocol? {
        return target.podVersionAbstracted
    }

    func getEstimatedBolusDeliveryTime() -> TimeInterval? {
        // Pass-through. No need to log.
        return target.getEstimatedBolusDeliveryTime()
    }
    
    func getEstimatedBolusRemaining() -> Int {
        // Pass-through. No need to log.
        return target.getEstimatedBolusRemaining()
    }
    
    var podCommState: PodCommState {
        // Pass-through. No need to log.
        return target.podCommState
    }
}
