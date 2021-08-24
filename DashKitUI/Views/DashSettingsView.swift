//
//  DashSettingsView.swift
//  ViewDev
//
//  Created by Pete Schwamb on 3/8/20.
//  Copyright © 2020 Pete Schwamb. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import DashKit
import HealthKit

struct DashSettingsView: View  {

   @ObservedObject var viewModel: DashSettingsViewModel

   @State private var showingDeleteConfirmation = false

   @State private var showSuspendOptions = false;
   
   @State private var showSyncTimeOptions = false;

   @Environment(\.guidanceColors) var guidanceColors
   @Environment(\.insulinTintColor) var insulinTintColor
   
   weak var navigator: DashUINavigator?
   
   private var daysRemaining: Int? {
      if case .timeRemaining(let remaining) = viewModel.lifeState, remaining > .days(1) {
         return Int(remaining.days)
      }
      return nil
   }

   private var hoursRemaining: Int? {
      if case .timeRemaining(let remaining) = viewModel.lifeState, remaining > .hours(1) {
         return Int(remaining.hours.truncatingRemainder(dividingBy: 24))
      }
      return nil
   }

   private var minutesRemaining: Int? {
      if case .timeRemaining(let remaining) = viewModel.lifeState, remaining < .hours(2) {
         return Int(remaining.minutes.truncatingRemainder(dividingBy: 60))
      }
      return nil
   }

   func timeComponent(value: Int, units: String) -> some View {
      Group {
         Text(String(value)).font(.system(size: 28)).fontWeight(.heavy)
         Text(units).foregroundColor(.secondary)
      }
   }

   var lifecycleProgress: some View {
      VStack(spacing: 2) {
         HStack(alignment: .lastTextBaseline, spacing: 3) {
            Text(self.viewModel.lifeState.localizedLabelText)
               .foregroundColor(self.viewModel.lifeState.labelColor(using: guidanceColors))
            Spacer()
            daysRemaining.map { (days) in
               timeComponent(value: days, units: days == 1 ?
                                LocalizedString("day", comment: "Unit for singular day in pod life remaining") :
                                LocalizedString("days", comment: "Unit for plural days in pod life remaining"))
            }
            hoursRemaining.map { (hours) in
               timeComponent(value: hours, units: hours == 1 ?
                                LocalizedString("hour", comment: "Unit for singular hour in pod life remaining") :
                                LocalizedString("hours", comment: "Unit for plural hours in pod life remaining"))
            }
            minutesRemaining.map { (minutes) in
               timeComponent(value: minutes, units: minutes == 1 ?
                                LocalizedString("minute", comment: "Unit for singular minute in pod life remaining") :
                                LocalizedString("minutes", comment: "Unit for plural minutes in pod life remaining"))
            }
         }
         ProgressView(progress: CGFloat(self.viewModel.lifeState.progress)).accentColor(self.viewModel.lifeState.progressColor(insulinTintColor: insulinTintColor, guidanceColors: guidanceColors))
      }
   }

   func cancelDelete() {
      showingDeleteConfirmation = false
   }


   var deliverySectionTitle: String {
      if self.viewModel.isScheduledBasal {
         return LocalizedString("Scheduled Basal", comment: "Title of insulin delivery section")
      } else {
         return LocalizedString("Insulin Delivery", comment: "Title of insulin delivery section")
      }
   }

   var deliveryStatus: some View {
      // podOK is true at this point. Thus there will be a basalDeliveryState
      VStack(alignment: .leading, spacing: 5) {
         Text(deliverySectionTitle)
            .foregroundColor(Color(UIColor.secondaryLabel))
         if let basalRate = self.viewModel.basalDeliveryRate {
            HStack(alignment: .center) {
               HStack(alignment: .lastTextBaseline, spacing: 3) {
                  Text(self.viewModel.basalRateFormatter.string(from: basalRate) ?? "")
                     .font(.system(size: 28))
                     .fontWeight(.heavy)
                     .fixedSize()
                  FrameworkLocalText("U/hr", comment: "Units for showing temp basal rate").foregroundColor(.secondary)
               }
            }
         } else {
            HStack(alignment: .center) {
               Image(systemName: "x.circle.fill")
                  .font(.system(size: 34))
                  .fixedSize()
                  .foregroundColor(guidanceColors.critical)
               FrameworkLocalText("No\nDelivery", comment: "Text shown in insulin remaining space when no pod is paired")
                  .fontWeight(.bold)
                  .fixedSize()
            }
         }
      }
   }

   func reservoir(filledPercent: CGFloat, fillColor: Color) -> some View {
      ZStack(alignment: Alignment(horizontal: .center, vertical: .center)) {
         GeometryReader { geometry in
            let offset = geometry.size.height * 0.05
            let fillHeight = geometry.size.height * 0.81
            Rectangle()
               .fill(fillColor)
               .mask(
                  Image(frameworkImage: "pod_reservoir_mask_swiftui")
                     .resizable()
                     .scaledToFit()
               )
               .mask(
                  Rectangle().path(in: CGRect(x: 0, y: offset + fillHeight - fillHeight * filledPercent, width: geometry.size.width, height: fillHeight * filledPercent))
               )
         }
         Image(frameworkImage: "pod_reservoir_swiftui")
            .renderingMode(.template)
            .resizable()
            .foregroundColor(fillColor)
            .scaledToFit()
      }.frame(width: 23, height: 32)
   }


   var reservoirStatus: some View {
      VStack(alignment: .trailing, spacing: 5) {
         Text(LocalizedString("Insulin Remaining", comment: "Header for insulin remaining on pod settings screen"))
            .foregroundColor(Color(UIColor.secondaryLabel))
         HStack {
            if let reservoirLevel = viewModel.reservoirLevel, let reservoirLevelHighlightState = viewModel.reservoirLevelHighlightState {
               reservoir(filledPercent: CGFloat(reservoirLevel.percentage), fillColor: reservoirColor(for: reservoirLevelHighlightState))
               Text(viewModel.reservoirText(for: reservoirLevel))
                  .font(.system(size: 28))
                  .fontWeight(.heavy)
                  .fixedSize()
            } else {
               Image(systemName: "exclamationmark.circle.fill")
                  .font(.system(size: 34))
                  .fixedSize()
                  .foregroundColor(guidanceColors.warning)

               FrameworkLocalText("No Pod", comment: "Text shown in insulin remaining space when no pod is paired").fontWeight(.bold)
            }

         }
      }
   }

   func suspendResumeButtonColor(for basalDeliveryState: PumpManagerStatus.BasalDeliveryState) -> Color {
      switch basalDeliveryState {
      case .active, .tempBasal, .cancelingTempBasal, .initiatingTempBasal:
         return .accentColor
      case .suspending, .resuming:
         return Color.secondary
      case .suspended:
         return guidanceColors.warning
      }
   }

   func suspendResumeRow(for basalState: PumpManagerStatus.BasalDeliveryState) -> some View {
      HStack {
         Button(action: {
            self.suspendResumeTapped()
         }) {
            HStack {
               Image(systemName: "pause.circle.fill")
                  .font(.system(size: 22))
                  .foregroundColor(suspendResumeButtonColor(for: basalState))
               Text(basalState.suspendResumeActionText)
                  .foregroundColor(basalState.suspendResumeActionColor)
            }
         }
         .actionSheet(isPresented: $showSuspendOptions) {
            suspendOptionsActionSheet
         }
         Spacer()
         if basalState.transitioning {
            ActivityIndicator(isAnimating: .constant(true), style: .medium)
         }
      }
   }

   private var doneButton: some View {
      Button("Done", action: {
         self.viewModel.doneTapped()
      })
   }

   var headerImage: some View {
      VStack(alignment: .center) {
         Image(frameworkImage: "Pod")
            .resizable()
            .aspectRatio(contentMode: ContentMode.fit)
            .frame(height: 100)
            .padding([.top,.horizontal])
      }.frame(maxWidth: .infinity)
   }

   var body: some View {
      List {
         Section() {
            VStack {
               if let mockPodCommManager = viewModel.podCommManager as? MockPodCommManager {
                  ZStack {
                     headerImage
                     NavigationLink(destination: MockPodSettingsView(model: MockPodSettingsViewModel(mockPodCommManager: mockPodCommManager))) {
                        EmptyView()
                     }
                     .buttonStyle(PlainButtonStyle())
                  }
               } else {
                  headerImage
               }

               lifecycleProgress

               HStack(alignment: .top) {
                  deliveryStatus
                  Spacer()
                  reservoirStatus
               }
            }
            if let notice = viewModel.notice {
               VStack(alignment: .leading, spacing: 4) {
                  Text(notice.title)
                     .font(Font.subheadline.weight(.bold))
                  Text(notice.description)
                     .font(Font.footnote.weight(.semibold))
               }.padding(.vertical, 8)
            }
         }

         Section(header: SectionHeader(label: LocalizedString("Activity", comment: "Section header for activity section"))) {
            suspendResumeRow(for: self.viewModel.basalDeliveryState ?? .active(Date()))
               .disabled(!self.viewModel.podOk)
            if case .suspended(let suspendDate) = self.viewModel.basalDeliveryState {
               HStack {
                  FrameworkLocalText("Suspended At", comment: "Label for suspended at time")
                  Spacer()
                  Text(self.viewModel.timeFormatter.string(from: suspendDate))
                     .foregroundColor(Color.secondary)
               }
            }
         }

         Section() {
            HStack {
               FrameworkLocalText("Pod Insertion", comment: "Label for pod insertion row")
               Spacer()
               Text(self.viewModel.activatedAtString)
                  .foregroundColor(Color.secondary)
            }

            HStack {
               FrameworkLocalText("Pod Expires", comment: "Label for pod expiration row")
               Spacer()
               Text(self.viewModel.expiresAtString)
                  .foregroundColor(Color.secondary)
            }

            if let podVersion = self.viewModel.podVersion {
               NavigationLink(destination: PodDetailsView(podVersion: podVersion)) {
                  FrameworkLocalText("Device Details", comment: "Text for device details disclosure row").foregroundColor(Color.primary)
               }
            } else {
               HStack {
                  FrameworkLocalText("Device Details", comment: "Text for device details disclosure row")
                  Spacer()
                  Text("—")
                     .foregroundColor(Color.secondary)
               }
            }
         }

         Section() {
            Button(action: {
               self.navigator?.navigateTo(self.viewModel.lifeState.nextPodLifecycleAction)
            }) {
               Text(self.viewModel.lifeState.nextPodLifecycleActionDescription)
                  .foregroundColor(self.viewModel.lifeState.nextPodLifecycleActionColor)
            }
         }

         Section(header: SectionHeader(label: LocalizedString("Configuration", comment: "Section header for configuration section")))
         {
            NavigationLink(destination:
                            NotificationSettingsView(
                              dateFormatter: self.viewModel.dateFormatter,
                              expirationReminderDefault: self.$viewModel.expirationReminderDefault,
                              scheduledReminderDate: self.viewModel.expirationReminderDate,
                              allowedScheduledReminderDates: self.viewModel.allowedScheduledReminderDates,
                              lowReservoirReminderValue: self.viewModel.lowReservoirAlertValue,
                              onSaveScheduledExpirationReminder: self.viewModel.saveScheduledExpirationReminder,
                              onSaveLowReservoirReminder: self.viewModel.saveLowReservoirReminder))
            {
               FrameworkLocalText("Notification Settings", comment: "Text for pod details disclosure row").foregroundColor(Color.primary)
            }
         }
         
         Section() {
            HStack {
               FrameworkLocalText("Pump Time", comment: "The title of the command to change pump time zone")
               Spacer()
               if viewModel.isClockOffset {
                  Image(systemName: "clock.fill")
                     .foregroundColor(guidanceColors.warning)
               }
               TimeView(timeZone: viewModel.timeZone)
                  .foregroundColor( viewModel.isClockOffset ? guidanceColors.warning : nil)
            }
            if viewModel.synchronizingTime {
               HStack {
                  FrameworkLocalText("Adjusting Pump Time...", comment: "Text indicating ongoing pump time synchronization")
                     .foregroundColor(.secondary)
                  Spacer()
                  ActivityIndicator(isAnimating: .constant(true), style: .medium)
               }
            } else if self.viewModel.timeZone != TimeZone.currentFixed {
               Button(action: {
                  showSyncTimeOptions = true
               }) {
                  FrameworkLocalText("Sync to Current Time", comment: "The title of the command to change pump time zone")
               }
               .actionSheet(isPresented: $showSyncTimeOptions) {
                  syncPumpTimeActionSheet
               }
            }
         }
         

         confidenceRemindersSection

         Section() {
            HStack {
               Text(LocalizedString("SDK Version", comment: "description label for sdk version in pod settings"))
               Spacer()
               Text(self.viewModel.sdkVersion)
            }
            self.viewModel.pdmIdentifier.map { (pdmIdentifier) in
               HStack {
                  Text(LocalizedString("PDM Identifier", comment: "description label for pdm identifier in pod settings"))
                  Spacer()
                  Text(pdmIdentifier)
               }
            }
         }

         if self.viewModel.lifeState.allowsPumpManagerRemoval {
            Section() {
               Button(action: {
                  self.showingDeleteConfirmation = true
               }) {
                  FrameworkLocalText("Switch to other insulin delivery device", comment: "Label for PumpManager deletion button")
                     .foregroundColor(guidanceColors.critical)
               }
               .actionSheet(isPresented: $showingDeleteConfirmation) {
                  removePumpManagerActionSheet
               }
            }
         }

         Section(header: SectionHeader(label: LocalizedString("Support", comment: "Label for support disclosure row"))) {
            NavigationLink(destination: Text("Not Implemented Yet")) {
               // Placeholder
               Text("Get Help with Omnipod 5").foregroundColor(Color.primary)
            }
         }

      }
      .alert(isPresented: $viewModel.alertIsPresented, content: { alert(for: viewModel.activeAlert!) })
      .insetGroupedListStyle()
      .navigationBarItems(trailing: doneButton)
      .navigationBarTitle(self.viewModel.viewTitle)
   }

   private var confidenceRemindersSection: some View {
      Section(footer: FrameworkLocalText("When enabled, your pod will audibly beep when you start a bolus, complete a bolus, and when you resume after suspending insulin delivery.", comment: "Descriptive text for confidence reminders section")) {
         Toggle(isOn: $viewModel.confidenceRemindersEnabled) {
            Text("Confidence Reminders")
         }
         .toggleStyle(SwitchToggleStyle(tint: insulinTintColor))
      }
   }
   
   var syncPumpTimeActionSheet: ActionSheet {
      ActionSheet(title: FrameworkLocalText("Time Change Detected", comment: "Title for pod sync time action sheet."), message: FrameworkLocalText("The time on your pump is different from the current time. Do you want to update the time on your pump to the current time?", comment: "Message for pod sync time action sheet"), buttons: [
         .default(FrameworkLocalText("Yes, Sync to Current Time", comment: "Button text to confirm pump time sync")) {
            self.viewModel.changeTimeZoneTapped()
         },
         .cancel(FrameworkLocalText("No, Keep Pump As Is", comment: "Button text to cancel pump time sync"))
      ])
   }

   var removePumpManagerActionSheet: ActionSheet {
      ActionSheet(title: FrameworkLocalText("Remove Pump", comment: "Title for Omnipod PumpManager deletion action sheet."), message: FrameworkLocalText("Are you sure you want to stop using Omnipod?", comment: "Message for Omnipod PumpManager deletion action sheet"), buttons: [
         .destructive(FrameworkLocalText("Delete Omnipod", comment: "Button text to confirm Omnipod PumpManager deletion")) {
            self.viewModel.stopUsingOmnipodTapped()
         },
         .cancel()
      ])
   }

   var suspendOptionsActionSheet: ActionSheet {
      ActionSheet(
         title: FrameworkLocalText("Delivery Suspension Reminder", comment: "Title for suspend duration selection action sheet"),
         message: FrameworkLocalText("How long would you like to suspend insulin delivery?", comment: "Message for suspend duration selection action sheet"),
         buttons: [
            .default(FrameworkLocalText("30 minutes", comment: "Button text for 30 minute suspend duration"), action: { self.viewModel.suspendDelivery(duration: .minutes(30)) }),
            .default(FrameworkLocalText("1 hour", comment: "Button text for 1 hour suspend duration"), action: { self.viewModel.suspendDelivery(duration: .hours(1)) }),
            .default(FrameworkLocalText("1 hour 30 minutes", comment: "Button text for 1 hour 30 minute suspend duration"), action: { self.viewModel.suspendDelivery(duration: .hours(1.5)) }),
            .default(FrameworkLocalText("2 hours", comment: "Button text for 2 hour suspend duration"), action: { self.viewModel.suspendDelivery(duration: .hours(2)) }),
            .cancel()
         ])
   }

   func suspendResumeTapped() {
      switch self.viewModel.basalDeliveryState {
      case .active, .tempBasal:
         showSuspendOptions = true
      case .suspended:
         self.viewModel.resumeDelivery()
      default:
         break
      }
   }

   private func alert(for alert: DashSettingsViewAlert) -> SwiftUI.Alert {
      switch alert {
      case .suspendError(let error):
         return SwiftUI.Alert(
            title: Text("Failed to Suspend Insulin Delivery", comment: "Alert title for suspend error"),
            message: Text(error.localizedDescription)
         )

      case .resumeError(let error):
         return SwiftUI.Alert(
            title: Text("Failed to Resume Insulin Delivery", comment: "Alert title for resume error"),
            message: Text(error.localizedDescription)
         )
         
      case .syncTimeError(let error):
         return SwiftUI.Alert(
            title: Text("Failed to Set Pump Time", comment: "Alert title for time sync error"),
            message: Text(error.localizedDescription)
         )
      }
   }

   func reservoirColor(for reservoirLevelHighlightState: ReservoirLevelHighlightState) -> Color {
      switch reservoirLevelHighlightState {
      case .normal:
         return insulinTintColor
      case .warning:
         return guidanceColors.warning
      case .critical:
         return guidanceColors.critical
      }
   }
}

struct DashSettingsView_Previews: PreviewProvider {
   static var previews: some View {
      DashSettingsSheetView()
   }
}


struct DashSettingsSheetView: View {

   @State var showingDetail = true

   var body: some View {
      VStack {
         Button(action: {
            self.showingDetail.toggle()
         }) {
            Text("Show Detail")
         }.sheet(isPresented: $showingDetail) {
            NavigationView {
               ZStack {
                  DashSettingsView(viewModel: previewModel(), navigator: nil)
               }
            }
         }
         HStack {
            Spacer()
         }
         Spacer()
      }
      .background(Color.green)
   }

   func previewModel() -> DashSettingsViewModel {
      let basalScheduleItems = [RepeatingScheduleValue(startTime: 0, value: 1.0)]
      let schedule = BasalRateSchedule(dailyItems: basalScheduleItems, timeZone: .current)!
      let state = DashPumpManagerState(basalRateSchedule: schedule, lastPodCommState: .active)!

      let mockPodCommManager = MockPodCommManager()
      let pumpManager = DashPumpManager(state: state, podCommManager: mockPodCommManager)
      let model = DashSettingsViewModel(pumpManager: pumpManager)
      model.basalDeliveryState = .active(Date())
      model.lifeState = .timeRemaining(.days(2.5))
      return model
   }
}
