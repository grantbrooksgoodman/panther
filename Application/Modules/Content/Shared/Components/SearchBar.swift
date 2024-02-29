//
//  SearchBar.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 05/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

public struct SearchBar: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.SearchBar
    private typealias Floats = AppConstants.CGFloats.SearchBar
    private typealias Strings = AppConstants.Strings.SearchBar

    // MARK: - Properties

    // CGFloat
    private let bottomPadding: CGFloat

    // String
    @Binding private var query: String
    @Localized(.search) private var textFieldPlaceholderText: String

    // MARK: - Init

    public init(
        _ query: Binding<String>,
        bottomPadding: CGFloat = AppConstants.CGFloats.SearchBar.defaultBottomPadding
    ) {
        _query = query
        self.bottomPadding = bottomPadding
    }

    // MARK: - View

    public var body: some View {
        HStack {
            HStack {
                Image(systemName: Strings.searchImageSystemName)
                    .foregroundStyle(Colors.searchImageForeground)
                    .imageScale(.medium)

                TextField(
                    textFieldPlaceholderText,
                    text: $query
                )
                .frame(height: Floats.textFieldFrameHeight)
                .submitLabel(.done)

                Button {
                    query = ""
                } label: {
                    Image(systemName: Strings.clearButtonImageSystemName)
                        .foregroundStyle(Colors.clearButtonImageForeground)
                        .opacity(query.isEmpty ? 0 : Floats.clearButtonImageOpacity)
                }
            }
            .padding(.horizontal, Floats.innerHStackHorizontalPadding)
            .background(ThemeService.isDarkModeActive ? Colors.innerHStackDarkBackground : Colors.innerHStackLightBackground)
            .cornerRadius(Floats.innerHStackCornerRadius)
        }
        .padding(.bottom, bottomPadding)
        .padding([.leading, .trailing])
        .background(Color.navigationBarBackground)
    }
}
