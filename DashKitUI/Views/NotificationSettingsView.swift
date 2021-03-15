//
//  NotificationSettingsView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 2/3/21.
//  Copyright © 2021 Tidepool. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import HealthKit

struct NotificationSettingsView: View {
    
    static let expirationReminderHoursAllowed = 1..<30
    
    var dateFormatter: DateFormatter
    
    @Binding var expirationReminderDefault: Int
    
    @State private var showingHourPicker: Bool = false
    
    var scheduledReminderDate: Date?
    
    var allowedScheduledReminderDates: [Date]?
    
    var lowReservoirReminderValue: Int
    
    var onSaveScheduledExpirationReminder: ((_ selectedDate: Date, _ completion: @escaping (_ error: Error?) -> Void) -> Void)?
    
    var onSaveLowReservoirReminder: ((_ selectedValue: Int, _ completion: @escaping (_ error: Error?) -> Void) -> Void)?
    
    var insulinQuantityFormatter = QuantityFormatter(for: .internationalUnit())

    var body: some View {
        RoundedCardScrollView {
            RoundedCard(
                title: LocalizedString("Omnipod Reminders", comment: "Title for omnipod reminders section"),
                footer: LocalizedString("The App notifies you in advance of Pod expiration.  Set the number of hours advance notice you would like to have.", comment: "Footer text for omnipod reminders section")
            ) {
                expirationReminderRow
            }

            if let scheduledReminderDate = scheduledReminderDate, let allowedDates = allowedScheduledReminderDates {
                RoundedCard(
                    footer: LocalizedString("This is a reminder that you scheduled when you paired your current Pod.", comment: "Footer text for scheduled reminder area"))
                {
                    Text("Scheduled Reminder")
                    Divider()
                    scheduledReminderRow(scheduledDate: scheduledReminderDate, allowedDates: allowedDates)
                }
            }

            RoundedCard(footer: LocalizedString("The App notifies you when the amount of insulin in the Pod reaches this level.", comment: "Footer text for low reservoir value row")) {
                lowReservoirValueRow
            }

            VStack(alignment: .leading) {
                RoundedCardTitle(LocalizedString("Critical Alerts", comment: "Title for critical alerts description"))
                    .padding(.bottom, 1)
                RoundedCardFooter(LocalizedString("The reminders above will not sound if your device is in Silent or Do Not Disturb mode.\n\nThere are other critical Pod alerts and alarms that will sound even if you device is set to Silent or Do Not Disturb mode.", comment: "Description text for critical alerts"))
            }
            .padding(.horizontal, 16)
        }
        .navigationBarTitle(LocalizedString("Notification Settings", comment: "navigation title for notification settings"))
    }
    
    var expirationDefaultFormatter = QuantityFormatter(for: .hour())
    
    var expirationDefaultString: String {
        return expirationValueString(expirationReminderDefault)
    }
    
    func expirationValueString(_ value: Int) -> String {
        return expirationDefaultFormatter.string(from: HKQuantity(unit: .hour(), doubleValue: Double(value)), for: .hour())!
    }

    
    var expirationReminderRow: some View {
        VStack {
            HStack {
                Text(LocalizedString("Expiration Reminder Default", comment: "Label text for expiration reminder default row"))
                Spacer()
                Button(expirationDefaultString) {
                    withAnimation {
                        showingHourPicker.toggle()
                    }
                }
            }
            if showingHourPicker {
                Picker("", selection: $expirationReminderDefault) {
                    ForEach(Self.expirationReminderHoursAllowed, id: \.self) { value in
                        Text(expirationValueString(value))
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 100)
                .clipped()
            }
        }
    }
    
    @State private var scheduleReminderDateEditViewIsShown: Bool = false
    
    private func scheduledReminderRow(scheduledDate: Date, allowedDates: [Date]) -> some View {
        Group {
            if scheduledDate <= Date() {
                scheduledReminderRowContents(disclosure: false)
            } else {
                NavigationLink(
                    destination: ScheduledExpirationReminderEditView(
                        scheduledExpirationReminderDate: scheduledDate,
                        allowedDates: allowedDates,
                        dateFormatter: dateFormatter,
                        onSave: onSaveScheduledExpirationReminder,
                        onFinish: { scheduleReminderDateEditViewIsShown = false }),
                    isActive: $scheduleReminderDateEditViewIsShown)
                {
                    scheduledReminderRowContents(disclosure: true)
                }
            }
        }
    }
    
    private func scheduledReminderRowContents(disclosure: Bool) -> some View {
        RoundedCardValueRow(
            label: LocalizedString("Time", comment: "Label for scheduled reminder value row"),
            value: dateFormatter.string(from: scheduledReminderDate ?? Date()),
            highlightValue: false,
            disclosure: disclosure
        )
    }


    @State private var lowReservoirReminderEditViewIsShown: Bool = false

    var lowReservoirValueRow: some View {
        NavigationLink(
            destination: LowReservoirReminderEditView(
                lowReservoirReminderValue: lowReservoirReminderValue,
                insulinQuantityFormatter: insulinQuantityFormatter,
                onSave: onSaveLowReservoirReminder,
                onFinish: { lowReservoirReminderEditViewIsShown = false }),
            isActive: $lowReservoirReminderEditViewIsShown)
        {
            RoundedCardValueRow(
                label: LocalizedString("Low Reservoir Reminder", comment: "Label for low reservoir reminder row"),
                value: insulinQuantityFormatter.string(from: HKQuantity(unit: .internationalUnit(), doubleValue: Double(lowReservoirReminderValue)), for: .internationalUnit()) ?? "",
                highlightValue: false,
                disclosure: true)
        }
    }
}

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView(dateFormatter: DateFormatter(), expirationReminderDefault: .constant(2), scheduledReminderDate: Date(), allowedScheduledReminderDates: [Date()], lowReservoirReminderValue: 20)
    }
}
