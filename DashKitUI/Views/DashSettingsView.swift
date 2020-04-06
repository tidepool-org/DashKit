//
//  DashSettingsView.swift
//  ViewDev
//
//  Created by Pete Schwamb on 3/8/20.
//  Copyright © 2020 Pete Schwamb. All rights reserved.
//

import SwiftUI
import LoopKitUI

struct DashSettingsView<Model>: View where Model: DashSettingsViewModelProtocol  {
    
    @ObservedObject var viewModel: Model
    
    weak var navigator: DashUINavigator?
    
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

                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(self.viewModel.lifeState.localizedLabelText)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                    Spacer()
                    Text("3").font(.title).fontWeight(.bold)
                    Text("days")
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
                ProgressView(progress: CGFloat(self.viewModel.lifeState.progress))
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

                if self.viewModel.lifeState.allowsPumpManagerRemoval {
                    NavigationLink(destination: EmptyView()) {
                        Text("Switch to other insulin delivery device")
                            .foregroundColor(Color.destructive)
                    }
                }
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
        .environment(\.horizontalSizeClass, .regular)
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
