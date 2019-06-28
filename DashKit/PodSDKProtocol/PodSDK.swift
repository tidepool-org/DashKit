//
//  PodSDK.swift
//  DashKit
//
//  Created by Pete Schwamb on 6/26/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import PodSDK

extension PodCommManager: PodCommManagerProtocol {

    // Asking for an SDK that provides PodStatus as a protocol. If that happens, this goes away.
    private func mapPodStatus(_ completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) -> (PodCommResult<PodStatus>) -> () {
        return { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let status):
                completion(.success(status))
            }
        }
    }

    public func deactivatePod(completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) {
        deactivatePod(completion: mapPodStatus(completion))
    }

    public func getPodStatus(completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) {
        getPodStatus(completion: mapPodStatus(completion))
    }

    public func playTestBeeps(completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) {
        playTestBeeps(completion: mapPodStatus(completion))
    }

    public func sendProgram(programType: ProgramType, beepOption: BeepOption?, completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) {
        sendProgram(programType: programType, beepOption: beepOption, completion: mapPodStatus(completion))
    }

    public func stopProgram(programType: StopProgramType, completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) {
        stopProgram(programType: programType, completion: mapPodStatus(completion))
    }

    public func updateAlertSetting(alertSetting: PodAlertSetting, completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) {
        updateAlertSetting(alertSetting: alertSetting, completion: mapPodStatus(completion))
    }

    public func silenceAlerts(alert: PodAlerts, completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) {
        silenceAlerts(alert: alert, completion: mapPodStatus(completion))
    }

    public func retryUnacknowledgedCommand(completion: @escaping (PodCommResult<PodStatusProtocol>) -> ()) {
        retryUnacknowledgedCommand(completion: mapPodStatus(completion))
    }
}

extension PodStatus: PodStatusProtocol {}

