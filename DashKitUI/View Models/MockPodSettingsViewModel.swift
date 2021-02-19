//
//  MockPodSettingsViewModel.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 1/7/21.
//  Copyright © 2021 Tidepool. All rights reserved.
//

import Foundation
import DashKit
import PodSDK

class MockPodSettingsViewModel: ObservableObject, Identifiable {
    public var mockPodCommManager: MockPodCommManager
    @Published var activeAlerts: PodAlerts
    var updatedReservoir: NSNumber?
    
    var reservoirString: String {
        didSet {
            updatedReservoir = numberFormatter.number(from: reservoirString)
        }
    }

    var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    init(mockPodCommManager: MockPodCommManager) {
        self.mockPodCommManager = mockPodCommManager
        
        let reservoirAmount: Double
        
        if let podStatus = mockPodCommManager.podStatus {
            self.activeAlerts = podStatus.activeAlerts
            reservoirAmount = podStatus.initialInsulinAmount - podStatus.insulinDelivered
        } else {
            self.activeAlerts = PodAlerts()
            reservoirAmount = 0
        }
        
        reservoirString = numberFormatter.string(from: reservoirAmount) ?? ""
        
        mockPodCommManager.addObserver(self, queue: DispatchQueue.main)
    }
    
    func issueAlert(_ alert: PodAlerts) {
        mockPodCommManager.issueAlerts(alert)
        
        if let podStatus = mockPodCommManager.podStatus {
            activeAlerts = podStatus.activeAlerts
        }
    }
    
    func clearAlert(_ alert: PodAlerts) {
        mockPodCommManager.clearAlerts(alert)
        
        if let podStatus = mockPodCommManager.podStatus {
            activeAlerts = podStatus.activeAlerts
        }
    }
    
    func triggerAlarm(_ alarm: SimulatedPodAlarm) {
        mockPodCommManager.triggerAlarm(alarm.alarmCode)
    }
    
    func triggerSystemError() {
        mockPodCommManager.triggerSystemError()
    }
    
    func applyPendingUpdates() {
        if let podStatus = mockPodCommManager.podStatus {
            if let value = numberFormatter.number(from: reservoirString) {
                mockPodCommManager.podStatus?.insulinDelivered = podStatus.initialInsulinAmount - Double(truncating: value)
            }
        }
        mockPodCommManager.dashPumpManager?.getPodStatus() { _ in }
    }
}

extension MockPodSettingsViewModel: MockPodCommManagerObserver {
    func mockPodCommManagerDidUpdate() {
        if let podStatus = mockPodCommManager.podStatus {
            self.activeAlerts = podStatus.activeAlerts
        }
    }
}

extension PodCommError {
    static var simulatedErrors: [PodCommError?] {
        return [
            nil,
            .unacknowledgedCommandPendingRetry,
            .notConnected,
            .failToConnect,
            .activationError(.activationPhase1NotCompleted),
            .bleCommunicationError,
            .bluetoothOff,
            .bluetoothUnauthorized,
            .internalError(.incompatibleProductId),
            .invalidAlertSetting,
            .invalidProgram,
            .invalidProgramStatus(nil),
            .messageSigningFailed,
            .nackReceived(.errorPodState),
            .noUnacknowledgedCommandToRetry
        ]
    }
}

enum SimulatedPodAlerts: String, CaseIterable {
    case lowReservoirAlert
    case suspendInProgress
    case podExpireImminent
    case podExpiring
    
    var podAlerts: PodAlerts {
        switch self {
        case .lowReservoirAlert:
            return PodAlerts.lowReservoir
        case .suspendInProgress:
            return PodAlerts.suspendInProgress
        case .podExpireImminent:
            return PodAlerts.podExpireImminent
        case .podExpiring:
            return PodAlerts.podExpiring
        }
    }
}

enum SimulatedPodAlarm: String, CaseIterable {
    case podExpired
    case emptyReservoir
    case occlusion
    case other
    
    var alarmCode: AlarmCode {
        switch self {
        case .podExpired:
            return .podExpired
        case .emptyReservoir:
            return .emptyReservoir
        case .occlusion:
            return .occlusion
        case .other:
            return .other
        }
    }
}

