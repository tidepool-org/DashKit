//
//  LowReservoirReminderEditView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 2/17/21.
//  Copyright © 2021 Tidepool. All rights reserved.
//

import SwiftUI
import LoopKit
import HealthKit

struct LowReservoirReminderEditView: View {
    
    var onSave: ((_ selectedValue: Int, _ completion: @escaping (_ error: Error?) -> Void) -> Void)?
    var onFinish: (() -> Void)?
    var insulinQuantityFormatter: QuantityFormatter

    private var initialValue: Int
    @State private var alertIsPresented: Bool = false
    @State private var error: Error?
    @State private var saving: Bool = false
    @State private var selectedValue: Int
    

    init(lowReservoirReminderValue: Int, insulinQuantityFormatter: QuantityFormatter, onSave: ((_ selectedValue: Int, _ completion: @escaping (_ error: Error?) -> Void) -> Void)? = nil, onFinish: (() -> Void)? = nil)
    {
        self.onSave = onSave
        self.onFinish = onFinish
        self.insulinQuantityFormatter = insulinQuantityFormatter
        self.initialValue = lowReservoirReminderValue
        self._selectedValue = State(initialValue: lowReservoirReminderValue)
    }
    
    var body: some View {
        contentWithCancel
    }
    
    var content: some View {
        VStack {
            RoundedCardScrollView(title: LocalizedString("Low Reservoir Reminder", comment: "Title for low reservoir reminder edit page")) {
                RoundedCard {
                    RoundedCardValueRow(
                        label: LocalizedString("Low Reservoir Reminder", comment: "Label for low reservoir reminder row"),
                        value: formatValue(selectedValue),
                        highlightValue: true
                    )
                    Picker("", selection: $selectedValue) {
                        ForEach(10..<50, id: \.self) { value in
                            Text(formatValue(value))
                        }
                    }.pickerStyle(WheelPickerStyle())
                }
            }
            Spacer()
            Button(action: saveTapped) {
                Text(saveButtonText)
                    .actionButtonStyle()
                    .padding()
                    .disabled(saving || !valueChanged)
            }
        }
        .navigationBarTitle("", displayMode: .inline)
        .alert(isPresented: $alertIsPresented, content: { alert(error: error) })
    }
    
    func formatValue(_ value: Int) -> String {
        return insulinQuantityFormatter.string(from: HKQuantity(unit: .internationalUnit(), doubleValue: Double(value)), for: .internationalUnit()) ?? ""
    }
    
    var saveButtonText: String {
        if saving {
            return LocalizedString("Saving...", comment: "button title for saving low reservoir reminder while saving")
        } else {
            return LocalizedString("Save", comment: "button title for saving low reservoir reminder")
        }
    }
    
    private func saveTapped() {
        saving = true
        self.onSave?(selectedValue) { (error) in
            saving = false
            if let error = error {
                self.error = error
                self.alertIsPresented = true
            } else {
                self.onFinish?()
            }
        }
    }
    
    private var valueChanged: Bool {
        return selectedValue != initialValue
    }
    
    private var contentWithCancel: some View {
        if saving {
            return AnyView(content
                .navigationBarBackButtonHidden(true)
            )
        } else if valueChanged {
            return AnyView(content
                .navigationBarBackButtonHidden(true)
                .navigationBarItems(leading: cancelButton)
            )
        } else {
            return AnyView(content)
        }
    }
    
    private var cancelButton: some View {
        Button(action: { self.onFinish?() } ) { Text(LocalizedString("Cancel", comment: "Button title for cancelling low reservoir reminder edit")) }
    }
    
    private func alert(error: Error?) -> SwiftUI.Alert {
        return SwiftUI.Alert(
            title: Text("Failed to Update Expiration Reminder", comment: "Alert title for error when updating low reservoir reminder"),
            message: Text(error?.localizedDescription ?? "No Error")
        )
    }
}

struct LowReservoirReminderEditView_Previews: PreviewProvider {
    static var previews: some View {
        LowReservoirReminderEditView(
            lowReservoirReminderValue: 20,
            insulinQuantityFormatter: QuantityFormatter(for: .internationalUnit()),
            onSave: { (_, _) in },
            onFinish: { }
        )
    }
}
