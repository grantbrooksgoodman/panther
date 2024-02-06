//
//  RegionMenu.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 05/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import Redux

public struct RegionMenu: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.RegionMenu
    private typealias Floats = AppConstants.CGFloats.RegionMenu

    // MARK: - Dependencies

    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State private var isPresented = false
    @Binding private var selectedRegionCode: String

    // MARK: - Init

    public init(_ selectedRegionCode: Binding<String>) {
        _selectedRegionCode = selectedRegionCode
    }

    // MARK: - View

    public var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            VStack {
                Image(uiImage: services.regionDetail.image(by: .regionCode(selectedRegionCode)) ?? .init())
                    .resizable()
                    .frame(
                        width: Floats.buttonLabelImageFrameWidth,
                        height: Floats.buttonLabelImageFrameHeight
                    )
                    .cornerRadius(Floats.buttonLabelImageCornerRadius)
                    .aspectRatio(contentMode: .fit)

                Text("+\(services.regionDetail.callingCode(regionCode: selectedRegionCode) ?? "1")")
                    .foregroundStyle(Colors.buttonLabelTextForeground)
                    .multilineTextAlignment(.center)
            }
            .frame(
                minWidth: Floats.buttonLabelVStackFrameMinWidth,
                minHeight: Floats.buttonLabelVStackFrameMinHeight
            )
            .background(
                RoundedRectangle(
                    cornerRadius: Floats.buttonLabelVStackBackgroundRectangleCornerRadius
                )
            )
            .foregroundStyle(colorScheme == .dark ? Colors.buttonLabelDarkForeground : Colors.buttonLabelLightForeground)
            .shadow(radius: Floats.buttonLabelVStackShadowRadius)
        }
        .popover(isPresented: $isPresented) {
            RegionPickerView(
                .init(
                    initialState: .init(
                        $isPresented,
                        selectedRegionCode: $selectedRegionCode
                    ),
                    reducer: RegionMenuReducer()
                )
            )
            .frame(maxWidth: .infinity, alignment: .top)
            .onAppear { services.haptics.generateFeedback(.medium) }
        }
    }
}

private struct RegionPickerView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.RegionMenu
    private typealias Floats = AppConstants.CGFloats.RegionMenu
    private typealias Strings = AppConstants.Strings.RegionMenu

    // MARK: - Dependencies

    @Dependency(\.commonServices.regionDetail) private var regionDetailService: RegionDetailService

    // MARK: - Properties

    @StateObject private var observer: ViewObserver<RegionMenuObserver>
    @State private var selectedRegionTitle = ""
    @StateObject private var viewModel: ViewModel<RegionMenuReducer>

    // MARK: - Bindings

    private var searchQueryBinding: Binding<String> {
        viewModel.binding(
            for: \.searchQuery,
            sendAction: { .searchQueryChanged($0) }
        )
    }

    // MARK: - Init

    public init(_ viewModel: ViewModel<RegionMenuReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
        _observer = .init(wrappedValue: .init(.init(viewModel)))
    }

    // MARK: - View

    public var body: some View {
        if viewModel.isPresented.wrappedValue {
            ScrollViewReader { proxy in
                SearchBar(searchQueryBinding)
                    .padding(.bottom, Floats.searchBarBottomPadding)
                    .background(Color.navigationBarBackground)

                if let regionTitles = viewModel.queriedRegionTitles {
                    listView(regionTitles: regionTitles)
                        .onAppear {
                            viewModel.send(.listViewAppeared(proxy: proxy))
                        }
                } else {
                    noResultsView
                }
            }
            .header(.text(.init(viewModel.headerLabelText)), showsDivider: false)
            .background(Color.navigationBarBackground)
            .ignoresSafeArea(.all)
            .onAppear {
                selectedRegionTitle = viewModel.selectedRegionTitle ?? ""
            }
        } else {
            EmptyView()
        }
    }

    private func listView(regionTitles: [String]) -> some View {
        List(regionTitles, id: \.self) { regionTitle in
            Button {
                selectedRegionTitle = regionTitle
                viewModel.send(.selectedRegionTitleChanged(regionTitle))
            } label: {
                HStack {
                    Image(uiImage: regionDetailService.image(by: .regionTitle(regionTitle)) ?? .init())
                        .resizable()
                        .frame(
                            width: Floats.listViewCellLabelImageFrameWidth,
                            height: Floats.listViewCellLabelImageFrameHeight
                        )
                        .cornerRadius(Floats.listViewCellLabelImageCornerRadius)
                        .aspectRatio(contentMode: .fit)

                    Text(regionTitle)
                        .font(.system(
                            size: Floats.listViewCellLabelSystemFontSize,
                            weight: .regular
                        ))
                        .foregroundStyle(Color.titleText)

                    if regionTitle == selectedRegionTitle {
                        Image(systemName: Strings.selectedCellImageSystemName)
                            .foregroundStyle(Colors.selectedCellImageForeground)
                            .padding(.leading, Floats.selectedCellImageLeadingPadding)
                    }
                }
            }
        }
    }

    private var noResultsView: some View {
        Group {
            Spacer()
            Text(viewModel.noResultsLabelText)
                .font(.system(size: Floats.noResultsLabelSystemFontSize, weight: .regular))
                .foregroundStyle(Colors.noResultsLabelTextForeground)
            Spacer()
        }
    }
}
