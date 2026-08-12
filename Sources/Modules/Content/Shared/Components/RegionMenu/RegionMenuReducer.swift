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

/// The reducer that drives the region picker presented by ``RegionMenu``.
///
/// The picker displays a searchable list of regions and writes its results back to the
/// presenting view through the bindings held in its state.
///
/// The picker's behavior contract:
///
/// - On appearance, the list scrolls to the currently selected region after a brief delay.
/// - The list displays the regions whose titles match the search query, or a no results message
///   when none match.
/// - Selecting a region writes its code to the selection binding, then dismisses the picker
///   after a brief delay.
///
/// - Important: ``State`` reads and writes its presentation and selection values through the
///   bindings supplied by the presenting view rather than storing them itself.
struct RegionMenuReducer: Reducer {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.RegionMenu

    // MARK: - Dependencies

    @Dependency(\.commonServices.regionDetail) private var regionDetailService: RegionDetailService
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Actions

    /// The actions the region picker can process.
    enum Action: @unchecked Sendable {
        /// An action that requests a presentation change, carrying a Boolean value that indicates
        /// whether the picker should be presented. Triggers ``runIsPresentedEffect(_:)`` after a
        /// brief delay.
        case isPresentedChanged(Bool)

        /// An action that indicates the region list appeared, carrying the proxy used to scroll
        /// to the current selection.
        case listViewAppeared(proxy: ScrollViewProxy)

        /// An action that applies the given presentation state to the presentation binding.
        case runIsPresentedEffect(Bool)

        /// An action that indicates the search query changed, carrying the new value.
        case searchQueryChanged(String)

        /// An action that indicates the user selected a region, carrying its display title.
        /// Records the region's code and dismisses the picker after a brief delay.
        case selectedRegionTitleChanged(String)
    }

    // MARK: - State

    /// The state of the region picker.
    struct State: Equatable {
        /* MARK: Properties */

        /// A binding to a Boolean value that indicates whether the picker is presented. Writing
        /// to this value presents or dismisses the picker.
        var isPresented: Binding<Bool>

        /// The localized text the no results label displays.
        @Localized(.noResults) var noResultsLabelText

        /// The search query the user has entered.
        var searchQuery = ""

        fileprivate var selectedRegionCode: Binding<String>

        /* MARK: Computed Properties */

        /// The localized text the picker's header displays.
        var headerLabelText: String {
            let localizedString = Localized(.selectCallingCode).wrappedValue
            guard RuntimeStorage.languageCode == "en" else { return localizedString }
            return localizedString.capitalized
        }

        /// The display titles of the regions matching the search query, or `nil` if none match.
        var queriedRegionTitles: [String]? {
            @Dependency(\.commonServices.regionDetail) var regionDetailService: RegionDetailService
            return regionDetailService.regionTitles(by: .searchTerm(searchQuery))
        }

        /// The display title of the selected region, or `nil` if it cannot be determined.
        var selectedRegionTitle: String? {
            @Dependency(\.commonServices.regionDetail) var regionDetailService: RegionDetailService
            return regionDetailService.regionTitles(
                by: .regionCode(selectedRegionCode.wrappedValue),
                titleFormat: .regionNameFirst
            )?.first
        }

        /* MARK: Init */

        /// Creates a state with the given presentation and selection bindings.
        ///
        /// - Parameters:
        ///   - isPresented: A binding that controls the picker's presentation.
        ///   - selectedRegionCode: A binding to the code of the selected region.
        init(
            _ isPresented: Binding<Bool>,
            selectedRegionCode: Binding<String>
        ) {
            self.isPresented = isPresented
            self.selectedRegionCode = selectedRegionCode
        }

        /* MARK: Equatable Conformance */

        /// Returns a Boolean value that indicates whether two states are equal, comparing the
        /// wrapped values of their bindings.
        static func == (
            left: State,
            right: State
        ) -> Bool {
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

    /// Updates the picker's state in response to the given action, returning any effect to run.
    ///
    /// - Parameters:
    ///   - state: The picker's current state, mutated in place.
    ///   - action: The action to process.
    ///
    /// - Returns: An effect for the system to run, or `.none`.
    func reduce(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .isPresentedChanged(isPresented):
            return .task(delay: .milliseconds(.init(Floats.delayMilliseconds))) {
                .runIsPresentedEffect(isPresented)
            }

        case let .listViewAppeared(proxy: proxy):
            let selectedRegionCode = state.selectedRegionCode.wrappedValue
            let selectedRegionTitle = state.selectedRegionTitle

            Task.delayed(by: .milliseconds(.init(Floats.delayMilliseconds))) { @MainActor in
                withAnimation {
                    proxy.scrollTo(selectedRegionTitle ?? selectedRegionCode, anchor: .top)
                }

                guard UIApplication.isFullyV26Compatible else { return }
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
        Task.delayed(by: .milliseconds(Floats.secondaryDelayMilliseconds)) { @MainActor in
            uiApplication
                .presentedViews
                .filter(\.canBecomeFirstResponder)
                .unique
                .forEach { $0.becomeFirstResponder() }

            uiApplication.resignFirstResponders()
        }
    }
}
