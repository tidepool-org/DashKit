//
//  CheckInsertedCannulaView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 4/3/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import SwiftUI
import LoopKitUI

struct CheckInsertedCannulaView: View {
    
    var wasInsertedProperly: ((Bool) -> Void)?

    var body: some View {
        GuidePage(content: {
            VStack {
                LeadingImage("Cannula Inserted")
            
                HStack {
                    FrameworkLocalText("Is the cannula inserted properly?", comment: "Question to confirm the cannula is inserted properly").bold()
                    Spacer()
                }
                HStack {
                    FrameworkLocalText("The window on the top of the Pod should be colored pink when the cannula is properly inserted into the skin.", comment: "Description of proper cannula insertion")
                    Spacer()
                }.padding(.vertical)
            }

        }) {
            VStack(spacing: 10) {
                Button(action: {
                    self.wasInsertedProperly?(false)
                }) {
                    Text(LocalizedString("No", comment: "Button label for user to answer cannula was not properly inserted"))
                        .actionButtonStyle(.destructive)
                }
                Button(action: {
                    self.wasInsertedProperly?(true)
                }) {
                    Text(LocalizedString("Yes", comment: "Button label for user to answer cannula was properly inserted"))
                        .actionButtonStyle(.primary)
                }
            }.padding()
        }
        .animation(.default)
        .navigationBarTitle("Check Cannula", displayMode: .automatic)
    }
}

struct CheckInsertedCannulaView_Previews: PreviewProvider {
    static var previews: some View {
        CheckInsertedCannulaView()
    }
}
