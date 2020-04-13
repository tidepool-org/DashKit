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
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    weak var navigator: DashUINavigator?
    
    private var daysRemaining: Int? {
        if case .timeRemaining(let remaining, _, _) = viewModel.lifeState, remaining > .days(1) {
            return Int(remaining.days)
        }
        return nil
    }
    
    private var hoursRemaining: Int? {
        if case .timeRemaining(let remaining, _, _) = viewModel.lifeState, remaining > .hours(1) {
            return Int(remaining.hours.truncatingRemainder(dividingBy: 24))
        }
        return nil
    }
    
    private var minutesRemaining: Int? {
        if case .timeRemaining(let remaining, _, _) = viewModel.lifeState, remaining < .hours(2) {
            return Int(remaining.minutes.truncatingRemainder(dividingBy: 60))
        }
        return nil
    }
    
    func timeComponent(value: Int, units: String) -> some View {
        Group {
            Text(String(value)).font(.title).fontWeight(.bold)
            Text(units).foregroundColor(.secondary)
        }
    }
    
    var lifecycleProgress: some View {
        VStack(spacing: 6) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(self.viewModel.lifeState.localizedLabelText)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                Spacer()
                daysRemaining.map { (days) in
                    timeComponent(value: days, units: days == 1 ? "day" : "days")
                }
                hoursRemaining.map { (hours) in
                    timeComponent(value: hours, units: hours == 1 ? "hour" : "hours")
                }
                minutesRemaining.map { (minutes) in
                    timeComponent(value: minutes, units: minutes == 1 ? "minute" : "minutes")
                }
            }
            ProgressView(progress: CGFloat(self.viewModel.lifeState.progress)).accentColor(self.viewModel.lifeState.progressColor)
        }
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

                HStack {
                    VStack(alignment: .leading) {
                        Text("Last Sync")
                            .foregroundColor(Color(UIColor.secondaryLabel))
                        HStack {
                            Image(systemName: "x.circle.fill")
                                .foregroundColor(Color(UIColor.secondaryLabel))
                            Text("No Pod").fontWeight(.bold)
                        }
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("Insulin Remaining")
                            .foregroundColor(Color(UIColor.secondaryLabel))
                        HStack {
                            Image(systemName: "x.circle.fill")
                                .foregroundColor(Color(UIColor.secondaryLabel))
                            
                            Text("No Pod").fontWeight(.bold)
                        }
                    }
                }.padding(.bottom, 8)
            }
            
            Section(header: Text("Pod").font(.headline).foregroundColor(Color.primary)) {
                self.viewModel.lifeState.deliveryState.map { (deliveryState) in
                    HStack {
                        Button(action: {
                            self.viewModel.suspendResumeTapped()
                        }) {
                            Text(deliveryState.suspendResumeActionText)
                                .foregroundColor(deliveryState.suspendResumeActionColor)
                        }
                        Spacer()
                        if deliveryState.transitioning {
                            ActivityIndicator(isAnimating: .constant(true), style: .medium)
                        }
                    }
                }
            }

            Section() {
                if self.viewModel.lifeState.allowsPumpManagerRemoval {
                    NavigationLink(destination: EmptyView()) {
                        Text("Switch to other insulin delivery device")
                            .foregroundColor(Color.destructive)
                    }
                }
                
                NavigationLink(destination: EmptyView()) {
                    Text("Pod Details").foregroundColor(Color.primary)
                }
                
                self.viewModel.lifeState.activatedAt.map { (activatedAt) in
                    HStack {
                        Text("Pod Insertion")
                        Spacer()
                        Text(self.dateFormatter.string(from: activatedAt))
                    }
                }

                self.viewModel.lifeState.activatedAt.map { (activatedAt) in
                    HStack {
                        Text("Pod Expires")
                        Spacer()
                        Text(self.dateFormatter.string(from: activatedAt + Pod.lifetime))
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
                if self.viewModel.lifeState.allowsPumpManagerRemoval {
                    NavigationLink(destination: EmptyView()) {
                        Text("Switch to other insulin delivery device")
                            .foregroundColor(Color.destructive)
                    }
                }
            }

            Section(header: Text("Support").font(.headline).foregroundColor(Color.primary)) {
                NavigationLink(destination: EmptyView()) {
                    Text("Get Help with Insulet Omnipod DASH").foregroundColor(Color.primary)
                }
            }

        }
        .listStyle(GroupedListStyle())
        .environment(\.horizontalSizeClass, self.horizontalSizeClass)
        .navigationBarTitle("Omnipod DASH", displayMode: .automatic)
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
                        DashSettingsView(viewModel: MockDashSettingsViewModel(), navigator: MockNavigator())
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
