//
//  DashSettingsView.swift
//  ViewDev
//
//  Created by Pete Schwamb on 3/8/20.
//  Copyright © 2020 Pete Schwamb. All rights reserved.
//

import SwiftUI
import LoopKitUI
import DashKit

struct DashSettingsView<Model>: View where Model: DashSettingsViewModelProtocol  {
    
    @ObservedObject var viewModel: Model
    
    @State private var showingDeleteConfirmation = false
    
    @State private var showSuspendOptions = false;
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
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
            Text(String(value)).font(.system(size: 28)).fontWeight(.bold)
            Text(units).foregroundColor(.secondary)
        }
    }
    
    var lifecycleProgress: some View {
        VStack(spacing: 10) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(self.viewModel.lifeState.localizedLabelText)
                    .foregroundColor(self.viewModel.lifeState.labelColor)
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
            ProgressView(progress: CGFloat(self.viewModel.lifeState.progress)).accentColor(self.viewModel.lifeState.progressColor)
        }
    }
    
    var timeZoneString: String {
        let localTimeZone = TimeZone.current
        let localTimeZoneName = localTimeZone.abbreviation() ?? localTimeZone.identifier
        
        let timeZoneDiff = TimeInterval(viewModel.timeZone.secondsFromGMT() - localTimeZone.secondsFromGMT())
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        let diffString = timeZoneDiff != 0 ? formatter.string(from: abs(timeZoneDiff)) ?? String(abs(timeZoneDiff)) : ""
        
        return String(format: LocalizedString("%1$@%2$@%3$@", comment: "The format string for displaying an offset from a time zone: (1: GMT)(2: -)(3: 4:00)"), localTimeZoneName, timeZoneDiff != 0 ? (timeZoneDiff < 0 ? "-" : "+") : "", diffString)
    }
    
    func cancelDelete() {
        showingDeleteConfirmation = false
    }
    
    var deliveryStatus: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(self.viewModel.basalDeliveryState.headerText)
                .foregroundColor(Color(UIColor.secondaryLabel))
            self.viewModel.basalDeliveryRate.map { (rate) in
                HStack(alignment: .center) {
                    BasalStateSwiftUIView(netBasalPercent: rate.netPercent)
                        .frame(width: 38, height: 20, alignment: .center)
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(self.viewModel.basalRateFormatter.string(from: rate.absoluteRate) ?? "")
                            .font(.system(size: 28))
                            .fontWeight(.bold)
                            .fixedSize()
                        FrameworkLocalText("U/hr", comment: "Units for showing temp basal rate").foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    var reservoirStatus: some View {
        VStack(alignment: .leading) {
            Text(LocalizedString("Insulin Remaining", comment: "Header for insulin remaining on pod settings screen"))
                .foregroundColor(Color(UIColor.secondaryLabel))
            HStack {
                Image(systemName: "x.circle.fill")
                    .foregroundColor(Color(UIColor.secondaryLabel))
                
                FrameworkLocalText("No Pod", comment: "Text shown in insulin remaining space when no pod is paired").fontWeight(.bold)
            }
        }
    }

    var suspendResumeRow: some View {
        HStack {
            Button(action: {
                self.suspendResumeTapped()
            }) {
                Text(self.viewModel.basalDeliveryState.suspendResumeActionText)
                    .foregroundColor(self.viewModel.basalDeliveryState.suspendResumeActionColor)
            }
            .actionSheet(isPresented: $showSuspendOptions) {
                suspendOptionsActionSheet
            }
            Spacer()
            if self.viewModel.basalDeliveryState.transitioning {
                ActivityIndicator(isAnimating: .constant(true), style: .medium)
            }
        }
    }
    
    private var doneButton: some View {
        Button("Done", action: {
            self.viewModel.doneTapped()
        })
    }
    
    var body: some View {
        List {
            VStack(alignment: .leading) {
                VStack(alignment: .center) {
                    Image(frameworkImage: "Pod")
                        .resizable()
                        .aspectRatio(contentMode: ContentMode.fit)
                        .frame(height: 100)
                        .padding([.top,.horizontal])
                }.frame(maxWidth: .infinity)
                
                lifecycleProgress

                if self.viewModel.podOk {
                    HStack(alignment: .top) {
                        deliveryStatus
                        Spacer()
                        reservoirStatus
                    }
                }
                self.viewModel.systemErrorDescription.map { (systemErrorDescription) in
                    Text(systemErrorDescription)
                        .foregroundColor(Color.secondary)
                }
            }.padding(.bottom, 8)
            
            if self.viewModel.podOk {
                Section(header: FrameworkLocalText("Pod", comment: "Section header for pod section").font(.headline).foregroundColor(Color.primary)) {
                    suspendResumeRow
                }

                Section() {
                    
                    self.viewModel.podVersion.map { (podVersion) in
                        NavigationLink(destination: PodDetailsView(podVersion: podVersion)) {
                            FrameworkLocalText("Pod Details", comment: "Text for pod details disclosure row").foregroundColor(Color.primary)
                        }
                    }
                        
                    self.viewModel.activatedAt.map { (activatedAt) in
                        HStack {
                            FrameworkLocalText("Pod Insertion", comment: "Label for pod insertion row")
                            Spacer()
                            Text(self.viewModel.dateFormatter.string(from: activatedAt))
                        }
                    }

                    self.viewModel.activatedAt.map { (activatedAt) in
                        HStack {
                            FrameworkLocalText("Pod Expiration", comment: "Label for pod expiration row")
                            Spacer()
                            Text(self.viewModel.dateFormatter.string(from: activatedAt + Pod.lifetime))
                        }
                    }
                    
                    
                    HStack {
                        if self.viewModel.timeZone != TimeZone.currentFixed {
                            Button(action: {
                                self.viewModel.changeTimeZoneTapped()
                            }) {
                                FrameworkLocalText("Change Time Zone", comment: "The title of the command to change pump time zone")
                            }
                        } else {
                            FrameworkLocalText("Schedule Time Zone", comment: "Label for row showing pump time zone")
                        }
                        Spacer()
                        Text(timeZoneString)
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
                            .foregroundColor(Color.red)
                    }
                    .actionSheet(isPresented: $showingDeleteConfirmation) {
                        removePumpManagerActionSheet
                    }
                }
            }

            Section(header: FrameworkLocalText("Support", comment: "Label for support disclosure row").font(.headline).foregroundColor(Color.primary)) {
                NavigationLink(destination: EmptyView()) {
                    // Placeholder
                    Text("Get Help with Insulet Omnipod").foregroundColor(Color.primary)
                }
            }

        }
        .listStyle(GroupedListStyle())
        .environment(\.horizontalSizeClass, self.horizontalSizeClass)
        .navigationBarItems(trailing: doneButton)
        .navigationBarTitle("Omnipod", displayMode: .automatic)
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
                        DashSettingsView(viewModel: MockDashSettingsViewModel.livePod(), navigator: MockNavigator())
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
}

