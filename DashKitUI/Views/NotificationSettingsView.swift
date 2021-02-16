//
//  NotificationSettingsView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 2/3/21.
//  Copyright © 2021 Tidepool. All rights reserved.
//

import SwiftUI
import LoopKitUI

struct NotificationSettingsView: View {
    
    var dateFormatter: DateFormatter
    
    @Binding var expirationReminderDefault: Int
    @State private var showingHourPicker: Bool = false
    
    @Binding var scheduledReminderDate: Date?
    @State private var showingDatePicker: Bool = false
    
    private var scheduledReminderBinding: Binding<Date> {
        Binding(
            get: { scheduledReminderDate ?? Date() },
            set: { scheduledReminderDate = $0 }
        )
    }

    @Binding var lowReservoirAlertValue: Int
    @State private var showingLowReservoirAlertPicker: Bool = false

    var body: some View {
        RoundedCardScrollView {
            RoundedCard(
                title: "Omnipod Reminders",
                footer: "The App notifies you in advance of Pod expiration.  Set the number of hours advance notice you would like to have."
            ) {
                expirationReminderPicker
                if scheduledReminderDate != nil {
                    Divider()
                    scheduledReminderPicker
                }
            }

            RoundedCard(footer: "The App notifies you when the amount of insulin in the Pod reaches this level.") {
                lowReservoirValuePicker
            }

            RoundedCardTitle("Critical Alerts")
                .padding(.bottom, 1)
            RoundedCardFooter("The reminders above will not sound if your device is in Silent or Do Not Disturb mode.\n\nThere are other critical Pod alerts and alarms that will sound even if you device is set to Silent or Do Not Disturb mode.")
        }
        .navigationBarTitle(LocalizedString("Notification Settings", comment: "navigation title for notification settings"))
    }
    
    var expirationReminderPicker: some View {
        VStack {
            HStack {
                Text("Expiration Reminder Default")
                Spacer()
                Button("\(expirationReminderDefault) h") {
                    withAnimation {
                        showingHourPicker.toggle()
                    }
                }
            }
            if showingHourPicker {
                Picker("Expiration Reminder Default", selection: $expirationReminderDefault) {
                    ForEach(1..<30, id: \.self) { value in
                        Text("\(value) h")
                    }
                }.pickerStyle(WheelPickerStyle())
            }
        }
    }
    
    var scheduledReminderPicker: some View {
        VStack {
            HStack {
                Text("Scheduled Reminder")
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button(
                    dateFormatter.string(from: scheduledReminderBinding.wrappedValue)
                ) {
                    withAnimation {
                        showingDatePicker.toggle()
                    }
                }
                .fixedSize(horizontal: true, vertical: true)
            }
            if showingDatePicker {
                DatePicker("", selection: scheduledReminderBinding)
                    .datePickerStyle(WheelDatePickerStyle())
            }
        }
    }
    
    var lowReservoirValuePicker: some View {
        VStack {
            HStack {
                Text("Low Reservoir Reminder")
                Spacer()
                Button("\(lowReservoirAlertValue) U") {
                    withAnimation {
                        showingLowReservoirAlertPicker.toggle()
                    }
                }
            }
            if showingLowReservoirAlertPicker {
                Picker("", selection: $lowReservoirAlertValue) {
                    ForEach(1..<50, id: \.self) { value in
                        Text("\(value) U")
                    }
                }.pickerStyle(WheelPickerStyle())
            }
        }
    }
}

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView(dateFormatter: DateFormatter(), expirationReminderDefault: .constant(2), scheduledReminderDate: .constant(Date()), lowReservoirAlertValue: .constant(10))
    }
}
