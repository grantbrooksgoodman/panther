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

    @Dependency(\.commonServices.regionDetail) private var regionDetailService: RegionDetailService

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
        ScrollViewReader { _ in
            Button {
                isPresented.toggle()
            } label: {
                VStack {
                    Image(uiImage: regionDetailService.image(by: .regionCode(selectedRegionCode)) ?? .init())
                        .resizable()
                        .frame(
                            width: Floats.buttonLabelImageFrameWidth,
                            height: Floats.buttonLabelImageFrameHeight
                        )
                        .cornerRadius(Floats.buttonLabelImageCornerRadius)
                        .aspectRatio(contentMode: .fit)

                    Text("+\(regionDetailService.callingCode(regionCode: selectedRegionCode) ?? "1")")
                        .foregroundColor(Colors.buttonLabelTextForeground)
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
                RegionPickerView($isPresented, selectedRegionCode: $selectedRegionCode)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .onAppear { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            }
        }
    }
}

private struct RegionPickerView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.RegionMenu
    private typealias Floats = AppConstants.CGFloats.RegionMenu
    private typealias Strings = AppConstants.Strings.RegionMenu

    // MARK: - Dependencies

    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
    @Dependency(\.commonServices.regionDetail) private var regionDetailService: RegionDetailService

    // MARK: - Properties

    // Bool
    @Binding private var isPresented: Bool

    // String
    @Localized(.selectCallingCode) private var headerLabelText
    @Localized(.noResults) private var noResultsLabelText
    @State private var query = ""
    @Binding private var selectedRegionCode: String

    // MARK: - Init

    public init(
        _ isPresented: Binding<Bool>,
        selectedRegionCode: Binding<String>
    ) {
        _isPresented = isPresented
        _selectedRegionCode = selectedRegionCode
    }

    // MARK: - View

    public var body: some View {
        if isPresented {
            ScrollViewReader { proxy in
                SearchBar($query)
                    .padding(.bottom, Floats.searchBarBottomPadding)
                    .background(Color.navigationBarBackground)

                if let regionTitles = regionDetailService.regionTitles(by: .searchTerm(query)) {
                    listView(regionTitles: regionTitles)
                        .onAppear {
                            coreGCD.after(.milliseconds(.init(Floats.dismissDelayMilliseconds))) {
                                withAnimation {
                                    proxy.scrollTo(
                                        regionDetailService.regionTitles(
                                            by: .regionCode(selectedRegionCode),
                                            titleFormat: .regionNameFirst
                                        )?.first ?? selectedRegionCode,
                                        anchor: .top
                                    )
                                }
                            }
                        }
                } else {
                    noResultsView
                }
            }
            .header(.text(.init(headerLabelText)), showsDivider: false, isThemed: true)
            .background(Color.navigationBarBackground)
            .ignoresSafeArea(.all)
        } else {
            EmptyView()
        }
    }

    private func listView(regionTitles: [String]) -> some View {
        List(regionTitles, id: \.self) { regionTitle in
            Button {
                selectedRegionCode = regionDetailService.regionCode(by: .regionTitle(regionTitle)) ?? ""
                coreGCD.after(.milliseconds(.init(Floats.dismissDelayMilliseconds))) {
                    self.isPresented = false
                }
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

                    if regionTitle == regionDetailService.regionTitles(by: .regionCode(selectedRegionCode), titleFormat: .regionNameFirst)?.first {
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
            Text(noResultsLabelText)
                .font(.system(size: Floats.noResultsLabelSystemFontSize, weight: .regular))
                .foregroundStyle(Colors.noResultsLabelTextForeground)
            Spacer()
        }
    }
}
