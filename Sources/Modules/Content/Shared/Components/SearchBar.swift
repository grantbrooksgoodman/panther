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

/* Proprietary */
import AppSubsystem
import ComponentKit

public struct SearchBar: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.SearchBar
    private typealias Floats = AppConstants.CGFloats.SearchBar
    private typealias Strings = AppConstants.Strings.SearchBar

    // MARK: - Properties

    private let bottomPadding: CGFloat
    private let keyboardType: UIKeyboardType?
    private let onSubmit: ((String) -> Void)?
    private let placeholderText: String

    @Binding private var query: String

    // MARK: - Init

    public init(
        _ query: Binding<String>,
        bottomPadding: CGFloat = AppConstants.CGFloats.SearchBar.defaultBottomPadding,
        keyboardType: UIKeyboardType? = nil,
        placeholderText: String = Localized(.search).wrappedValue,
        onSubmit: ((String) -> Void)? = nil
    ) {
        _query = query
        self.bottomPadding = bottomPadding
        self.keyboardType = keyboardType
        self.placeholderText = placeholderText
        self.onSubmit = onSubmit
    }

    // MARK: - View

    public var body: some View {
        HStack {
            HStack {
                Components.symbol(
                    Strings.searchImageSystemName,
                    foregroundColor: Colors.searchImageForeground
                )

                TextField(
                    placeholderText,
                    text: $query
                )
                .dynamicTypeSize(.large)
                .frame(height: Floats.textFieldFrameHeight)
                .ifLet(keyboardType) { textField, keyboardType in
                    textField
                        .keyboardType(keyboardType)
                }
                .minimumScaleFactor(Floats.textFieldMinimumScaleFactor)
                .submitLabel(.done)
                .onSubmit { onSubmit?(query) }

                Components.button(
                    symbolName: Strings.clearButtonImageSystemName,
                    foregroundColor: Colors.clearButtonImageForeground
                ) {
                    query = ""
                }
                .opacity(query.isEmpty ? 0 : Floats.clearButtonImageOpacity)
            }
            .padding(.horizontal, Floats.innerHStackHorizontalPadding)
            .if(
                UIApplication.v26FeaturesEnabled,
                {
                    $0
                        .glassEffect(padding: Floats.glassEffectPadding)
                },
                else: {
                    $0
                        .background(ThemeService.isDarkModeActive ? Colors.innerHStackDarkBackground : Colors.innerHStackLightBackground)
                        .cornerRadius(Floats.innerHStackCornerRadius)
                }
            )
        }
        .padding(.bottom, bottomPadding)
        .padding(.horizontal, UIApplication.v26FeaturesEnabled ? Floats.v26HorizontalPadding : nil)
        .background(UIApplication.v26FeaturesEnabled ? Color.clear : .navigationBarBackground)
    }

    // MARK: - View Builder

    @ViewBuilder
    static func inView(
        withQuery query: Binding<String>,
        keyboardType: UIKeyboardType? = nil,
        placeholderText: String = Localized(.search).wrappedValue,
        onSubmit: ((String) -> Void)? = nil,
        content: @escaping () -> some View
    ) -> some View {
        if UIApplication.v26FeaturesEnabled {
            ZStack {
                content()

                VStack {
                    Spacer()
                    SearchBar(
                        query,
                        keyboardType: keyboardType,
                        placeholderText: placeholderText,
                        onSubmit: onSubmit
                    )
                }
            }
        } else {
            VStack(spacing: 0) {
                SearchBar(
                    query,
                    keyboardType: keyboardType,
                    placeholderText: placeholderText,
                    onSubmit: onSubmit
                )

                content()
            }
        }
    }
}
