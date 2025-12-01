//
//  NavigationWindow.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 24/06/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

struct NavigationWindow: View {
    // MARK: - Properties

    private let content: () -> any View
    private let displayMode: NavigationBarItem.TitleDisplayMode
    private let isBackButtonHidden: Bool
    private let toolbarBackgroundColor: Color?
    private let toolbarTitle: Toolbar.TitleConfiguration?
    private let toolbarItems: [Toolbar.Item]?

    // MARK: - Init

    init(
        displayMode: NavigationBarItem.TitleDisplayMode = .automatic,
        isBackButtonHidden: Bool = false,
        toolbarBackgroundColor: Color? = nil,
        toolbarItems: [Toolbar.Item]? = nil,
        toolbarTitle: Toolbar.TitleConfiguration? = nil,
        content: @escaping () -> any View
    ) {
        self.displayMode = displayMode
        self.isBackButtonHidden = isBackButtonHidden
        self.toolbarBackgroundColor = toolbarBackgroundColor
        self.toolbarItems = toolbarItems
        self.toolbarTitle = toolbarTitle
        self.content = content
    }

    // MARK: - View

    var body: some View {
        NavigationView {
            content()
                .eraseToAnyView()
                .navigationBarTitleDisplayMode(displayMode)
                .ifLet(toolbarTitle) { contentView, toolbarTitle in
                    contentView
                        .navigationTitle(
                            Text(toolbarTitle.text)
                                .font(ComponentKit.Font.systemSemibold.model)
                                .foregroundStyle(toolbarTitle.color)
                        )
                }
                .ifLet(toolbarItems) { contentView, toolbarItems in
                    contentView
                        .toolbar { Toolbar(toolbarItems) }
                }
        }
        .accentColor(Color.accent)
        .ifLet(toolbarBackgroundColor) { navigationView, toolbarBackgroundColor in
            navigationView
                .toolbarBackground(toolbarBackgroundColor, for: .navigationBar)
        }
        .if(isBackButtonHidden) {
            $0
                .navigationBarBackButtonHidden()
        }
    }
}

extension NavigationWindow {
    struct Toolbar: ToolbarContent {
        // MARK: - Properties

        private let items: [NavigationWindow.Toolbar.Item]

        // MARK: - Computed Properties

        private var leadingItems: [NavigationWindow.Toolbar.Item] { items.filter { $0.placement.toolbarItemPlacement == .topBarLeading } }

        private var principalItems: [NavigationWindow.Toolbar.Item] { items.filter { $0.placement.toolbarItemPlacement == .principal } }

        private var trailingItems: [NavigationWindow.Toolbar.Item] { items.filter { $0.placement.toolbarItemPlacement == .topBarTrailing } }

        // MARK: - Init

        init(_ items: [NavigationWindow.Toolbar.Item]) {
            self.items = items
        }

        // MARK: - View

        @ToolbarContentBuilder
        var body: some ToolbarContent {
            if !leadingItems.isEmpty {
                ToolbarItemGroup(placement: .topBarLeading) {
                    ForEach(leadingItems) {
                        $0.content().eraseToAnyView()
                    }
                }
            }

            if !principalItems.isEmpty {
                ToolbarItemGroup(placement: .principal) {
                    ForEach(principalItems) {
                        $0.content().eraseToAnyView()
                    }
                }
            }

            if !trailingItems.isEmpty {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ForEach(trailingItems) {
                        $0.content().eraseToAnyView()
                    }
                }
            }
        }
    }
}

extension NavigationWindow.Toolbar {
    struct Item: Identifiable {
        // MARK: - Types

        enum Placement {
            /* MARK: Cases */

            case principal
            case topBarLeading
            case topBarTrailing

            /* MARK: Properties */

            var toolbarItemPlacement: ToolbarItemPlacement {
                switch self {
                case .principal: .principal
                case .topBarLeading: .topBarLeading
                case .topBarTrailing: .topBarTrailing
                }
            }
        }

        // MARK: - Properties

        let content: () -> any View
        let id: AnyHashable
        let placement: Placement

        // MARK: - Init

        init(
            placement: Placement,
            content: @escaping () -> any View
        ) {
            id = placement.hashValue
            self.placement = placement
            self.content = content
        }
    }
}

extension NavigationWindow.Toolbar {
    struct TitleConfiguration {
        // MARK: - Properties

        let color: Color
        let text: String

        // MARK: - Init

        init(
            _ text: String,
            color: Color = .navigationBarTitle
        ) {
            self.text = text
            self.color = color
        }
    }
}

extension ToolbarItemPlacement: @retroactive Equatable {
    public static func == (left: ToolbarItemPlacement, right: ToolbarItemPlacement) -> Bool {
        String(describing: left) == String(describing: right)
    }
}
