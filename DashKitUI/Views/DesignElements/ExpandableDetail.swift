//
//  ExpandableDetail.swift
//  ViewDev
//
//  Created by Pete Schwamb on 3/4/20.
//  Copyright © 2020 Pete Schwamb. All rights reserved.
//

import SwiftUI

struct ExpandableDetail<Content, DetailContent>: View where Content: View, DetailContent: View {
    
    let content: Content
    let detailContent: DetailContent
    @Binding var detailShown: Bool

    init(detailShown: Binding<Bool>,
         @ViewBuilder content: @escaping () -> Content,
         @ViewBuilder detailContent: @escaping () -> DetailContent)
    {
        _detailShown = detailShown
        self.content = content()
        self.detailContent = detailContent()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                self.content
            }
            // Solid color provides cover for detail sliding in/out
            .background(Color(UIColor.systemBackground))
            .zIndex(1)
            if (self.detailShown) {
                Rectangle()
                    .foregroundColor(Color(UIColor.secondarySystemBackground))
                    .frame(height: 2)
                    .padding(.top, 8)
                    // Solid color provides cover for detail sliding in/out
                    .background(Color(UIColor.systemBackground))
                    .padding(.bottom, 8)
                    .zIndex(1)
                self.detailContent
            }
        }
    }
}

struct ExpandableDetail_Previews: PreviewProvider {
    static var previews: some View {
        ExpandableDetailWrapper()
    }
    
    struct ExpandableDetailWrapper: View {
        @State private var panelShown: Bool = false
        
        var body: some View {
            HStack(alignment: .top) {
                VStack {
                    ExpandableDetail(detailShown: $panelShown, content: {
                        VStack {
                            Text("Some text")
                            Text("Some more text")
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                    }) {
                        VStack {
                            Text("Detail item 1")
                            Text("Detail item 2")
                        }
                    }
                    .frame(maxWidth:.infinity)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(5)
                    .padding()
                    
                    Button(action: {
                        withAnimation {
                            self.panelShown.toggle()
                        }
                    }) {
                        Text("Toggle Detail")
                    }
                    Spacer()
                }
            }
        }
    }
}
