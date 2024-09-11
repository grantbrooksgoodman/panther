//
//  StaticListView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

public struct StaticListView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.StaticListView
    private typealias Floats = AppConstants.CGFloats.StaticListView

    // MARK: - Properties

    private let items: [StaticListItem]

    @State private var selectedItem: StaticListItem?

    // MARK: - Init

    public init(_ items: [StaticListItem]) {
        self.items = items
    }

    // MARK: - View

    public var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .center, spacing: 0) {
                List {
                    ForEach(items, id: \.self) { item in
                        if ThemeService.isDarkModeActive {
                            cellView(item)
                                .disabled(!item.isEnabled)
                                .listRowBackground(selectedItem == item ? Colors.cellViewSelectedDarkBackground : Colors.cellViewDefaultDarkBackground)
                        } else {
                            cellView(item)
                                .disabled(!item.isEnabled)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .onAppear {
                    proxy.scrollTo(0, anchor: .top)
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: (Floats.frameMaxHeightPrimaryMultiplier * .init(items.count)) + (Floats.frameMaxHeightSecondaryMultiplier * .init(items.count))
        )
        .clipShape(
            RoundedRectangle(
                cornerSize: .init(
                    width: Floats.clipShapeRoundedRectangleCornerSizeWidth,
                    height: Floats.clipShapeRoundedRectangleCornerSizeHeight
                ),
                style: .continuous
            )
        )
    }

    @ViewBuilder
    private func cellView(_ item: StaticListItem) -> some View {
        if let action = item.action {
            if ThemeService.isDarkModeActive {
                Button {} label: {
                    labelView(item)
                }
                .contentShape(Rectangle())
                ._onButtonGesture { isPressed in
                    selectedItem = isPressed ? item : nil
                } perform: {
                    action()
                }
            } else {
                Button {
                    action()
                } label: {
                    labelView(item)
                }
            }
        } else if let destination = item.destination {
            NavigationLink {
                AnyView(destination())
            } label: {
                labelView(item)
            }
        } else {
            labelView(item)
        }
    }

    private func labelView(_ item: StaticListItem) -> some View {
        HStack {
            if let imageData = item.imageData {
                imageData.image
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(Floats.imageCornerRadius)
                    .foregroundStyle(imageData.color)
                    .frame(width: Floats.imageFrameWidth, height: Floats.imageFrameHeight)
            }

            Components.text(item.title)
                .padding(.leading, Floats.labelLeadingPadding)

            Spacer()
        }
    }
}
