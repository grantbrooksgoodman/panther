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

/// A rounded search field with a leading search symbol and a trailing clear button.
///
/// Use ``SearchBar`` to filter a page's content by a search query. The bar binds to the given
/// query, shows its clear button only while the query is non-empty, and runs an optional handler
/// with the current query when the user submits.
///
/// To combine the bar with the content it filters, use
/// ``inView(withQuery:keyboardType:placeholderText:onSubmit:content:)``.
///
/// - Note: When the app runs with full iOS 26 compatibility, the bar renders with a glass
///   effect; otherwise, it renders with a filled, rounded background.
struct SearchBar: View {
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

    /// Creates a search bar with the given query binding and configuration.
    ///
    /// - Parameters:
    ///   - query: A binding to the search query the bar displays and edits.
    ///   - bottomPadding: The padding applied below the bar.
    ///   - keyboardType: The keyboard type to display during editing, or `nil` for the system
    ///     default.
    ///   - placeholderText: The placeholder string to display while the query is empty. Defaults
    ///     to the localized search prompt.
    ///   - onSubmit: The handler to run with the current query when the user submits, if any.
    init(
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

    /// The content and behavior of the view.
    var body: some View {
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
                UIApplication.isFullyV26Compatible
            ) {
                $0
                    .glassEffect(padding: Floats.glassEffectPadding)
            } else: {
                $0
                    .background(ThemeService.isDarkModeActive ? Colors.innerHStackDarkBackground : Colors.innerHStackLightBackground)
                    .cornerRadius(Floats.innerHStackCornerRadius)
            }
        }
        .padding(.bottom, bottomPadding)
        .padding(.horizontal, UIApplication.isFullyV26Compatible ? Floats.v26HorizontalPadding : nil)
        .background(UIApplication.isFullyV26Compatible ? Color.clear : .navigationBarBackground)
    }

    // MARK: - View Builder

    /// Creates a view that combines a search bar with the given content.
    ///
    /// When the app runs with full iOS 26 compatibility, the bar floats at the bottom of the
    /// content; otherwise, it sits above the content.
    ///
    /// - Parameters:
    ///   - query: A binding to the search query the bar displays and edits.
    ///   - keyboardType: The keyboard type to display during editing, or `nil` for the system
    ///     default.
    ///   - placeholderText: The placeholder string to display while the query is empty. Defaults
    ///     to the localized search prompt.
    ///   - onSubmit: The handler to run with the current query when the user submits, if any.
    ///   - content: The content the search bar filters.
    ///
    /// - Returns: A view that lays out the search bar together with the given content.
    @ViewBuilder
    static func inView(
        withQuery query: Binding<String>,
        keyboardType: UIKeyboardType? = nil,
        placeholderText: String = Localized(.search).wrappedValue,
        onSubmit: ((String) -> Void)? = nil,
        content: @escaping () -> some View
    ) -> some View {
        if UIApplication.isFullyV26Compatible {
            ZStack {
                content()
                    .padding(.bottom, NavigationBar.height)

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
