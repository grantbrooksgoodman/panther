//
//  RegionMenuReducer.swift
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

public struct RegionMenuReducer: Reducer {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.RegionMenu

    // MARK: - Dependencies

    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
    @Dependency(\.commonServices.regionDetail) private var regionDetailService: RegionDetailService
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Actions

    public enum Action {
        case isPresentedChanged(Bool)
        case listViewAppeared(proxy: ScrollViewProxy)
        case runIsPresentedEffect(Bool)
        case searchQueryChanged(String)
        case selectedRegionTitleChanged(String)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        // Bool
        public var isPresented: Binding<Bool>

        // String
        @Localized(.selectCallingCode) public var headerLabelText
        @Localized(.noResults) public var noResultsLabelText
        public var searchQuery = ""
        public var selectedRegionCode: Binding<String>

        /* MARK: Computed Properties */

        public var queriedRegionTitles: [String]? {
            @Dependency(\.commonServices.regionDetail) var regionDetailService: RegionDetailService
            return regionDetailService.regionTitles(by: .searchTerm(searchQuery))
        }

        public var selectedRegionTitle: String? {
            @Dependency(\.commonServices.regionDetail) var regionDetailService: RegionDetailService
            return regionDetailService.regionTitles(
                by: .regionCode(selectedRegionCode.wrappedValue),
                titleFormat: .regionNameFirst
            )?.first
        }

        /* MARK: Init */

        public init(
            _ isPresented: Binding<Bool>,
            selectedRegionCode: Binding<String>
        ) {
            self.isPresented = isPresented
            self.selectedRegionCode = selectedRegionCode
        }

        /* MARK: Equatable Conformance */

        public static func == (left: State, right: State) -> Bool {
            let sameIsPresented = left.isPresented.wrappedValue == right.isPresented.wrappedValue
            let sameHeaderLabelText = left.headerLabelText == right.headerLabelText
            let sameNoResultsLabelText = left.noResultsLabelText == right.noResultsLabelText
            let sameSearchQuery = left.searchQuery == right.searchQuery
            let sameSelectedRegionCode = left.selectedRegionCode.wrappedValue == right.selectedRegionCode.wrappedValue

            guard sameIsPresented,
                  sameHeaderLabelText,
                  sameNoResultsLabelText,
                  sameSearchQuery,
                  sameSelectedRegionCode else { return false }

            return true
        }
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .isPresentedChanged(isPresented):
            return .task(delay: .milliseconds(.init(Floats.delayMilliseconds))) {
                .runIsPresentedEffect(isPresented)
            }

        case let .listViewAppeared(proxy: proxy):
            let selectedRegionCode = state.selectedRegionCode.wrappedValue
            let selectedRegionTitle = state.selectedRegionTitle

            coreGCD.after(.milliseconds(.init(Floats.delayMilliseconds))) {
                withAnimation {
                    proxy.scrollTo(selectedRegionTitle ?? selectedRegionCode, anchor: .top)
                }

                guard UIApplication.v26FeaturesEnabled else { return }
                showCurrentSelection()
            }

        case let .runIsPresentedEffect(isPresented):
            state.isPresented.wrappedValue = isPresented

        case let .searchQueryChanged(searchQuery):
            state.searchQuery = searchQuery

        case let .selectedRegionTitleChanged(selectedRegionTitle):
            state.selectedRegionCode.wrappedValue = regionDetailService.regionCode(by: .regionTitle(selectedRegionTitle)) ?? ""
            return .task(delay: .milliseconds(.init(Floats.delayMilliseconds))) {
                .isPresentedChanged(false)
            }
        }

        return .none
    }

    // MARK: - Auxiliary

    /// - NOTE: Fixes a bug in which the initial appearance of the list view in iOS 26 would not display the current selection.
    private func showCurrentSelection() {
        coreGCD.after(.milliseconds(Floats.secondaryDelayMilliseconds)) {
            uiApplication
                .presentedViews
                .filter(\.canBecomeFirstResponder)
                .unique
                .forEach { $0.becomeFirstResponder() }

            uiApplication.resignFirstResponders()
        }
    }
}
