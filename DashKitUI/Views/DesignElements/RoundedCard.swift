//
//  RoundedCard.swift
//  SectionedUIPlaygroundApp
//
//  Created by Pete Schwamb on 2/9/21.
//

import SwiftUI

struct RoundedCardTitle: View {
    var title: String
    
    init(_ title: String) {
        self.title = title
    }
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
    }
}

struct RoundedCardFooter: View {
    var text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
            .foregroundColor(.secondary)
    }
}


struct RoundedCard<Content: View>: View {
    var content: () -> Content
    var alignment: HorizontalAlignment
    var title: String?
    var footer: String?

    init(title: String? = nil, footer: String? = nil, alignment: HorizontalAlignment = .leading, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.alignment = alignment
        self.title = title
        self.footer = footer
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if let title = title {
                RoundedCardTitle(title)
                    .frame(maxWidth: .infinity, alignment: Alignment(horizontal: .leading, vertical: .center))
            }
            VStack(content: content)
                .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            if let footer = footer {
                RoundedCardFooter(footer)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 20)
    }
}

struct RoundedCardScrollView<Content: View>: View {
    var content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, content: content)
                .padding()
        }
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
    }
}
