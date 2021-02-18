//
//  ScheduledExpirationReminderEditView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 2/17/21.
//  Copyright © 2021 Tidepool. All rights reserved.
//

import SwiftUI

struct ScheduledExpirationReminderEditView: View {
    
    var allowedReminderDateRange: ClosedRange<Date>
    var dateFormatter: DateFormatter
    var onSave: ((_ selectedDate: Date, _ completion: @escaping (_ error: Error?) -> Void) -> Void)?
    var onFinish: (() -> Void)?

    private var initialValue: Date?
    @State private var alertIsPresented: Bool = false
    @State private var error: Error?
    @State private var saving: Bool = false
    @State private var selectedDate: Date

    init(scheduledExpirationReminderDate: Date, allowedReminderDateRange: ClosedRange<Date>, dateFormatter: DateFormatter, onSave: ((_ selectedDate: Date, _ completion: @escaping (_ error: Error?) -> Void) -> Void)? = nil, onFinish: (() -> Void)? = nil)
    {
        self.allowedReminderDateRange = allowedReminderDateRange
        self.dateFormatter = dateFormatter
        self.onSave = onSave
        self.onFinish = onFinish
        self.initialValue = scheduledExpirationReminderDate
        self._selectedDate = State(initialValue: scheduledExpirationReminderDate)
    }
    
    var body: some View {
        contentWithCancel
    }
    
    var content: some View {
        VStack {
            RoundedCardScrollView(title: LocalizedString("Scheduled Reminder", comment: "Title for scheduled expiration reminder edit page")) {
                RoundedCard {
                    RoundedCardValueRow(
                        label: LocalizedString("Scheduled Reminder", comment: "Label for scheduled expiration reminder row"),
                        value: dateFormatter.string(from: selectedDate),
                        highlightValue: true
                    )
                    DatePicker("", selection: $selectedDate, in: allowedReminderDateRange)
                        .datePickerStyle(WheelDatePickerStyle())
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
    
    var saveButtonText: String {
        if saving {
            return LocalizedString("Saving...", comment: "button title for saving scheduled reminder while saving")
        } else {
            return LocalizedString("Save", comment: "button title for saving scheduled reminder")
        }
    }
    
    private func saveTapped() {
        saving = true
        self.onSave?(selectedDate) { (error) in
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
        return selectedDate != initialValue
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
        Button(action: { self.onFinish?() } ) { Text(LocalizedString("Cancel", comment: "Button title for cancelling scheduled reminder date edit")) }
    }
    
    private func alert(error: Error?) -> SwiftUI.Alert {
        return SwiftUI.Alert(
            title: Text("Failed to Update Expiration Reminder", comment: "Alert title for error when updating expiration reminder"),
            message: Text(error?.localizedDescription ?? "No Error")
        )
    }
}

struct ScheduledExpirationReminderEditView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduledExpirationReminderEditView(
            scheduledExpirationReminderDate: Date(),
            allowedReminderDateRange: Calendar.current.date(byAdding: .day, value: -2, to: Date())!...Date(),
            dateFormatter: DateFormatter(),
            onSave: { (_, _) in },
            onFinish: { }
        )
    }
}
