//
//  MockPodSettings.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 8/22/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import SwiftUI
import DashKit
import PodSDK

extension PodCommError {
    fileprivate static var simulatedErrors: [PodCommError?] {
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

struct MockPodSettingsView: View {
    let mockPodCommManager: MockPodCommManager
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State private var showAlertActions: Bool = false
    @State private var selectedAlert: SimulatedPodAlerts?
    
    func podCommErrorFormatted(_ error: PodCommError?) -> String {
        if let error = error {
            return error.localizedDescription
        } else {
            return "No error"
        }
    }
    

    var body: some View {

        return Form {
            Section {
                sendProgramErrorPicker
                unacknowledgedCommandRetryResultPicker
            }
            
            Section(header: Text("Reservoir Remaining").font(.headline).foregroundColor(Color.primary)) {
                reservoirRemainingEntry
            }
            
            Section(header: Text("Alerts").font(.headline).foregroundColor(Color.primary)) {
                ForEach(SimulatedPodAlerts.allCases, id: \.self) { item in
                    Button(action: {
                        if self.mockPodCommManager.podStatus.activeAlerts.contains(item.podAlerts) {
                            self.mockPodCommManager.clearAlerts(item.podAlerts)
                        } else {
                            self.selectedAlert = item
                            self.showAlertActions = true
                        }
                    }) {
                        HStack {
                            Text("\(item.rawValue)")
                            Spacer()
                            if self.mockPodCommManager.podStatus.activeAlerts.contains(item.podAlerts) {
                                Image(systemName: "checkmark.rectangle")
                            }
                        }
                    }
                }
            }
            .actionSheet(isPresented: $showAlertActions) {
                ActionSheet(
                    title: Text("\(selectedAlert!.rawValue)"),
                    buttons: [
                        .cancel(),
                        .default(Text("Issue Immediately")) { self.mockPodCommManager.issueAlerts(selectedAlert!.podAlerts) },
                        .default(Text("Issue in 15s")) { DispatchQueue.main.asyncAfter(deadline: .now() + 15) { self.mockPodCommManager.issueAlerts(selectedAlert!.podAlerts) } },
                    ]
                )
            }
        }
        .navigationBarTitle("Mock Pod Settings")
    }
    
    var unacknowledgedCommandRetryResultPicker: some View {
        let unacknowledgedCommandRetryResultBinding = Binding<Bool>(get: {
            if let result = self.mockPodCommManager.unacknowledgedCommandRetryResult {
                return result.hasPendingCommandProgrammed
            } else {
                return false
            }
        }, set: {
            self.mockPodCommManager.unacknowledgedCommandRetryResult = $0 ? PendingRetryResult.wasProgrammed : PendingRetryResult.wasNotProgrammed
        })
        
        return Toggle(isOn: unacknowledgedCommandRetryResultBinding) {
            Text("Unacknowledged Command Was Received By Pod")
        }
    }
    
    var sendProgramErrorPicker: some View {
        let sendProgramErrorBinding = Binding<Int>(get: {
            let idx = PodCommError.simulatedErrors.firstIndex {
                $0?.localizedDescription ?? "" == self.mockPodCommManager.deliveryProgramError?.localizedDescription ?? ""
            }
            return idx ?? 0
        }, set: {
            self.mockPodCommManager.deliveryProgramError = PodCommError.simulatedErrors[$0]
        })
        return Picker(selection: sendProgramErrorBinding, label: Text("Delivery Program Error")) {
            ForEach(0 ..< PodCommError.simulatedErrors.count) {
                Text(self.podCommErrorFormatted(PodCommError.simulatedErrors[$0]))
            }
        }
    }
    
    var reservoirRemainingEntry: some View {
        var numberFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 2
            return formatter
        }

        let reservoirRemaining = Binding(
            get: {
                return numberFormatter.string(from: Double(self.mockPodCommManager.podStatus.reservoirUnitsRemaining) / Pod.podSDKInsulinMultiplier) ?? ""
            },
            set: {
                if let reservoirRemaining = numberFormatter.number(from: $0) {
                    self.mockPodCommManager.podStatus.reservoirUnitsRemaining = Int(reservoirRemaining.doubleValue * Pod.podSDKInsulinMultiplier)
                }
            }
        )
        
        return MockPodReservoirRemainingEntryView(reservoirRemaining: reservoirRemaining)
    }

}

struct MockPodReservoirRemainingEntryView: View {
    @Binding var reservoirRemaining: String

    var body: some View {
        // TextField only updates continuously as the user types if the value is a String
        TextField("Enter reservoir remaining value",
                  text: $reservoirRemaining)
            .keyboardType(.decimalPad)
    }
}

struct MockPodSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MockPodSettingsView(mockPodCommManager: MockPodCommManager())
    }
}
