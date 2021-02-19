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
    
    var allowedReminderDateRange: ClosedRange<Date>
    
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
                if let scheduledReminderDate = scheduledReminderDate  {
                    Divider()
                    scheduledReminderRow(scheduledDate: scheduledReminderDate)
                }
            }

            RoundedCard(footer: LocalizedString("The App notifies you when the amount of insulin in the Pod reaches this level.", comment: "Footer text for low reservoir value row")) {
                lowReservoirValueRow
            }

            RoundedCardTitle(LocalizedString("Critical Alerts", comment: "Title for critical alerts description"))
                .padding(.bottom, 1)
            RoundedCardFooter(LocalizedString("The reminders above will not sound if your device is in Silent or Do Not Disturb mode.\n\nThere are other critical Pod alerts and alarms that will sound even if you device is set to Silent or Do Not Disturb mode.", comment: "Description text for critical alerts"))
        }
        .navigationBarTitle(LocalizedString("Notification Settings", comment: "navigation title for notification settings"))
    }
    
    var expirationReminderRow: some View {
        VStack {
            HStack {
                Text(LocalizedString("Expiration Reminder Default", comment: "Label text for expiration reminder default row"))
                Spacer()
                Button("\(expirationReminderDefault) h") {
                    withAnimation {
                        showingHourPicker.toggle()
                    }
                }
            }
            if showingHourPicker {
                Picker("", selection: $expirationReminderDefault) {
                    ForEach(Self.expirationReminderHoursAllowed, id: \.self) { value in
                        Text("\(value) h")
                    }
                }.pickerStyle(WheelPickerStyle())
            }
        }
    }
    
    @State private var scheduleReminderDateEditViewIsShown: Bool = false
    
    func scheduledReminderRow(scheduledDate: Date) -> some View {
        NavigationLink(
            destination: ScheduledExpirationReminderEditView(
                scheduledExpirationReminderDate: scheduledDate,
                allowedReminderDateRange: allowedReminderDateRange,
                dateFormatter: dateFormatter,
                onSave: onSaveScheduledExpirationReminder,
                onFinish: { scheduleReminderDateEditViewIsShown = false }),
            isActive: $scheduleReminderDateEditViewIsShown)
        {
            RoundedCardValueRow(
                label: LocalizedString("Scheduled Reminder", comment: "Label for scheduled reminder row"),
                value: dateFormatter.string(from: scheduledReminderDate ?? Date()),
                highlightValue: false,
                disclosure: true
            )
        }
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
        NotificationSettingsView(dateFormatter: DateFormatter(), expirationReminderDefault: .constant(2), scheduledReminderDate: Date(), allowedReminderDateRange: Calendar.current.date(byAdding: .day, value: -2, to: Date())!...Date(), lowReservoirReminderValue: 20)
    }
}
