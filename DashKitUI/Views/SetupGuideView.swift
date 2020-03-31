//
//  SetupGuideView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 2/7/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import SwiftUI

struct SetupGuideView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.secondarySystemBackground).edgesIgnoringSafeArea(.all)
                PairPodSetupView()
            }
            .navigationBarTitle("Insert Cannula", displayMode: .automatic)
        }
    }
}

struct SetupGuideView_Previews: PreviewProvider {
    static var previews: some View {
        SetupGuideView()
    }
}
