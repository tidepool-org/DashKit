//
//  LeadingImage.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/12/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import SwiftUI

struct LeadingImage: View {
    
    var name: String
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    init(_ name: String) {
        self.name = name
    }
    
    var body: some View {
        Image(frameworkImage: self.name, decorative: true)
            .resizable()
            .aspectRatio(contentMode: ContentMode.fit)
            .frame(height: self.verticalSizeClass == .compact ? 70 : 150)
            .padding(.vertical, self.verticalSizeClass == .compact ? 0 : nil)
    }
}

struct LeadingImage_Previews: PreviewProvider {
    static var previews: some View {
        LeadingImage("Pod")
    }
}
