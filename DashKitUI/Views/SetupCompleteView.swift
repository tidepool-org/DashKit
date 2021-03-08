//
//  SetupCompleteView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/2/21.
//  Copyright © 2021 Tidepool. All rights reserved.
//

import SwiftUI
import LoopKitUI
import PodSDK
import DashKit

struct SetupCompleteView: View {
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.appName) private var appName

    
    private var onSaveScheduledExpirationReminder: ((_ selectedDate: Date, _ completion: @escaping (_ error: Error?) -> Void) -> Void)?
    private var didFinish: () -> Void
    private var didRequestDeactivation: () -> Void
    private var dateFormatter: DateFormatter

    @State private var configuredReminderDate: Date

    @State private var scheduleReminderDateEditViewIsShown: Bool = false

    var allowedReminderDateRange: ClosedRange<Date>

    init(reminderDate: Date, dateFormatter: DateFormatter, allowedReminderDateRange: ClosedRange<Date>, onSaveScheduledExpirationReminder: ((_ selectedDate: Date, _ completion: @escaping (_ error: Error?) -> Void) -> Void)?, didFinish: @escaping () -> Void, didRequestDeactivation: @escaping () -> Void)
    {
        self._configuredReminderDate = State(initialValue: reminderDate)
        self.dateFormatter = dateFormatter
        self.allowedReminderDateRange = allowedReminderDateRange
        self.onSaveScheduledExpirationReminder = onSaveScheduledExpirationReminder
        self.didFinish = didFinish
        self.didRequestDeactivation = didRequestDeactivation
    }
    
    var body: some View {
        GuidePage(content: {
            VStack {
                LeadingImage("Pod")
                Text(String(format: LocalizedString("Your Pod is ready for use.\n\n%1$@ will remind you to change your pod before it expires. You can change this to a time convenient for you.", comment: "Format string for instructions for setup complete view. (1: app name)"), appName))
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                HStack {
                    NavigationLink(
                        destination: ScheduledExpirationReminderEditView(
                            scheduledExpirationReminderDate: configuredReminderDate,
                            allowedReminderDateRange: allowedReminderDateRange,
                            dateFormatter: dateFormatter,
                            onSave: onSaveScheduledExpirationReminder,
                            onFinish: { scheduleReminderDateEditViewIsShown = false }),
                        isActive: $scheduleReminderDateEditViewIsShown)
                    {
                        RoundedCardValueRow(
                            label: LocalizedString("Expiration Reminder", comment: "Label for expiration reminder row"),
                            value: dateFormatter.string(from: configuredReminderDate),
                            highlightValue: false
                        )
                    }
                }
            }
            .padding(.bottom, 8)
            .accessibility(sortPriority: 1)
        }) {
            Button(action: {
                didFinish()
            }) {
                Text(LocalizedString("Finish Setup", comment: "Action button title to continue at Setup Complete"))
                    .actionButtonStyle(.primary)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .zIndex(1)
        }
        .animation(.default)
        .navigationBarTitle("Setup Complete", displayMode: .automatic)
    }
}
struct SetupCompleteView_Previews: PreviewProvider {
    static var previews: some View {
        SetupCompleteView(
            reminderDate: Date(),
            dateFormatter: DateFormatter(),
            allowedReminderDateRange: Calendar.current.date(byAdding: .day, value: -2, to: Date())!...Date(),
            onSaveScheduledExpirationReminder: { (date, completion) in
            },
            didFinish: {
            },
            didRequestDeactivation: {
            }
        )
    }
}
