//
//  MockPodSettings.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 8/22/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import SwiftUI
import LoopKitUI
import PodSDK
import DashKit

struct MockPodSettingsView: View {
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @ObservedObject var model: MockPodSettingsViewModel
    
    @State private var showAlertActions: Bool = false
    @State private var selectedAlert: SimulatedPodAlerts?
    
    @State private var showAlarmActions: Bool = false
    @State private var selectedAlarm: SimulatedPodAlarm?
    
    @State private var showSystemErrorActions: Bool = false

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
                nextCommsErrorPicker
                unacknowledgedCommandRetryResultPicker
            }
            
            Section(header: SectionHeader(label: "Reservoir Remaining")) {
                reservoirRemainingEntry
            }

            Section(header: SectionHeader(label: "Activation Date")) {
                activatedAtEntry
            }
            
            Section(header: SectionHeader(label: "Alerts")) {
                ForEach(SimulatedPodAlerts.allCases, id: \.self) { item in
                    Button(action: {
                        if self.model.activeAlerts.contains(item.podAlerts) {
                            self.model.clearAlert(item.podAlerts)
                        } else {
                            self.selectedAlert = item
                            self.showAlertActions = true
                        }
                    }) {
                        HStack {
                            Text("\(item.rawValue)")
                            Spacer()
                            if self.model.activeAlerts.contains(item.podAlerts) {
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
                        .default(Text("Issue Immediately")) {
                            self.model.issueAlert(selectedAlert!.podAlerts)
                            self.selectedAlert = nil
                        },
                        .default(Text("Issue in 15s")) { DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                            self.model.issueAlert(selectedAlert!.podAlerts)
                        } },
                    ]
                )
            }
            Section(header: SectionHeader(label: "Alarms")) {
                ForEach(SimulatedPodAlarm.allCases, id: \.self) { item in
                    Button(action: {
                        self.selectedAlarm = item
                        self.showAlarmActions = true
                    }) {
                        Text("\(item.rawValue)")
                    }
                }
            }
            .actionSheet(isPresented: $showAlarmActions) {
                ActionSheet(
                    title: Text("\(selectedAlarm!.rawValue)"),
                    buttons: [
                        .cancel(),
                        .default(Text("Issue Immediately")) {
                            self.model.triggerAlarm(selectedAlarm!)
                            self.selectedAlert = nil
                        },
                        .default(Text("Issue in 15s")) { DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                            self.model.triggerAlarm(selectedAlarm!)
                        } },
                    ]
                )
            }
            Section(header: SectionHeader(label: "System Errors")) {
                Button(action: {
                    self.showSystemErrorActions = true
                }) {
                    Text("Trigger System Error")
                }
            }
            .actionSheet(isPresented: $showSystemErrorActions) {
                ActionSheet(
                    title: Text("System Error"),
                    buttons: [
                        .cancel(),
                        .default(Text("Issue Immediately")) {
                            self.model.triggerSystemError()
                        },
                        .default(Text("Issue in 15s")) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                                self.model.triggerSystemError()
                            }
                        },
                    ]
                )
            }
        }
        .onDisappear {
            self.model.applyPendingUpdates()
        }
        .navigationBarTitle("Mock Pod Settings")
    }
    
    var unacknowledgedCommandRetryResultPicker: some View {
        let unacknowledgedCommandRetryResultBinding = Binding<Bool>(get: {
            if let result = self.model.mockPodCommManager.unacknowledgedCommandRetryResult {
                return result.hasPendingCommandProgrammed
            } else {
                return false
            }
        }, set: {
            self.model.mockPodCommManager.unacknowledgedCommandRetryResult = $0 ? PendingRetryResult.wasProgrammed : PendingRetryResult.wasNotProgrammed
        })
        
        return Toggle(isOn: unacknowledgedCommandRetryResultBinding) {
            Text("Unacknowledged Command Was Received By Pod")
        }
    }
    
    var nextCommsErrorPicker: some View {
        let nextCommsErrorBinding = Binding<Int>(get: {
            let idx = PodCommError.simulatedErrors.firstIndex {
                $0?.localizedDescription ?? "" == self.model.mockPodCommManager.nextCommsError?.localizedDescription ?? ""
            }
            return idx ?? 0
        }, set: {
            model.nextCommsError = PodCommError.simulatedErrors[$0]
        })
        return Picker(selection: nextCommsErrorBinding, label: Text("Next Comms Error")) {
            ForEach(0 ..< PodCommError.simulatedErrors.count) {
                Text(self.podCommErrorFormatted(PodCommError.simulatedErrors[$0]))
            }
        }
    }
    
    var reservoirRemainingEntry: some View {
        return MockPodReservoirRemainingEntryView(reservoirRemaining: $model.reservoirString)
    }

    var activatedAtEntry: some View {
        DatePicker("Activated", selection: $model.activationDate)
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
        MockPodSettingsView(model: MockPodSettingsViewModel(mockPodCommManager: MockPodCommManager()))
    }
}
