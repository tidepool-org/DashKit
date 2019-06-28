//
//  MockPodCommManager.swift
//  DashKitTests
//
//  Created by Pete Schwamb on 6/27/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import DashKit
import PodSDK

struct MockPodStatus: PodStatusProtocol {
    var podState: PodState!

    var programStatus: ProgramStatus!

    var activeAlerts: PodAlerts!

    var isOcclusionAlertActive: Bool!

    var bolusUnitsRemaining: Int

    var totalUnitsDelivered: Int

    var reservoirUnitsRemaining: Int

    var timeElapsedSinceActivation: TimeInterval

    var activationTime: Date

    func hasAlerts() -> Bool {
        return !activeAlerts.isEmpty
    }
}

class MockPodCommManager: PodCommManagerProtocol {

    var lastBolusVolume: Int?
    var lastBasalProgram: BasalProgram?
    var lastTempBasal: TempBasal?

    var podStatus: MockPodStatus

    var sendProgramFailureError: PodCommError?

    var delegate: PodCommManagerDelegate?

    func setLogger(logger: LoggingProtocol) {
        return
    }

    func enableAutoConnection(launchOptions: [AnyHashable : Any]?) {
        return
    }

    func startPodActivation(lowReservoirAlert: LowReservoirAlert?, podExpirationAlert: PodExpirationAlert?, eventListener: @escaping (ActivationStatus<ActivationStep1Event>) -> ()) {
        return
    }

    func finishPodActivation(basalProgram: BasalProgram, autoOffAlert: AutoOffAlert?, eventListener: @escaping (ActivationStatus<ActivationStep2Event>) -> ()) {
        return
    }

    func discardPod(completion: @escaping (PodCommResult<Bool>) -> ()) {
        return
    }

    func deactivatePod(completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) {
        return
    }

    func getPodStatus(completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) {
        return
    }

    func getAlertsDetails(completion: @escaping (PodCommResult<PodAlerts>) -> ()) {
        return
    }

    func playTestBeeps(completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) {
        return
    }

    func sendProgram(programType: ProgramType, beepOption: BeepOption?, completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) {
        if let error = sendProgramFailureError {
            completion(.failure(error))
        } else {
            switch programType {
            case .basalProgram(let program):
                lastBasalProgram = program
            case .bolus(let bolus):
                lastBolusVolume = bolus.immediateVolume
            case .tempBasal(let tempBasal):
                lastTempBasal = tempBasal
            }
            completion(.success(podStatus))
        }
    }

    func stopProgram(programType: StopProgramType, completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) {
        return
    }

    func updateAlertSetting(alertSetting: PodAlertSetting, completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) {
        return
    }

    func silenceAlerts(alert: PodAlerts, completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) {
        return
    }

    func retryUnacknowledgedCommand(completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) {
        return
    }

    func clearUnacknowledgedCommand() {
        return
    }

    func getPodId() -> String? {
        return "MockPodID"
    }

    func getEstimatedBolusDeliveryTime() -> TimeInterval? {
        return nil
    }

    func getEstimatedBolusRemaining() -> Int {
        return 0
    }

    var podCommState: PodCommState {
        return PodCommState.init(rawValue: "todo")!
    }

    init(podStatus: MockPodStatus? = nil) {
        if let podStatus = podStatus {
            self.podStatus = podStatus
        } else {
            self.podStatus = MockPodStatus(
                podState: .runningAboveMinVolume,
                programStatus: .basalRunning,
                activeAlerts: PodAlerts([]),
                isOcclusionAlertActive: false,
                bolusUnitsRemaining: 0,
                totalUnitsDelivered: 38,
                reservoirUnitsRemaining: 1023,
                timeElapsedSinceActivation: 2,
                activationTime: Date())
        }
    }
}

extension PodStatus {
    init?(podState: PodState = .runningAboveMinVolume,
          programStatus: ProgramStatus = ProgramStatus.basalRunning,
          activeAlerts: PodAlerts = PodAlerts(rawValue: 0),
          isOcclusionAlertActive: Bool = false,
          bolusUnitsRemaining: Int = 0,
          totalUnitsDelivered: Int = 38,
          reservoirUnitsRemaining: Int = 1023,
          timeElapsedSinceActivation: Int = 2,
          lastSequenceNumber: Int = 10) {

        self.init(JSON: [
            "programStatus": programStatus.rawValue,
            "lastSequenceNumber": lastSequenceNumber,
            "podState": podState.rawValue,
            "activeAlerts": activeAlerts.rawValue,
            "isOcclusionAlertActive": isOcclusionAlertActive,
            "pulsesDelivered": totalUnitsDelivered,
            "reservoirPulsesRemaining": reservoirUnitsRemaining,
            "timeSinceActivation": timeElapsedSinceActivation,
            "bolusPulsesRemaining": bolusUnitsRemaining
            ])
    }
}
