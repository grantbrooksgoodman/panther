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

/* 3rd-party */
import Redux

public struct RegionMenuReducer: Reducer {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.RegionMenu

    // MARK: - Dependencies

    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
    @Dependency(\.commonServices.regionDetail) private var regionDetailService: RegionDetailService

    // MARK: - Actions

    public enum Action {
        case isPresentedChanged(Bool)
        case listViewAppeared(proxy: ScrollViewProxy)
        case searchQueryChanged(String)
        case selectedRegionTitleChanged(String)
    }

    // MARK: - Feedback

    public enum Feedback {
        case isPresentedChanged(Bool)
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

    // MARK: - Init

    public init() { RuntimeStorage.store(#file, as: .presentedViewName) }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case let .action(.isPresentedChanged(isPresented)):
            return .task(delay: .milliseconds(.init(Floats.dismissDelayMilliseconds))) {
                .isPresentedChanged(isPresented)
            }

        case let .action(.listViewAppeared(proxy: proxy)):
            let selectedRegionCode = state.selectedRegionCode.wrappedValue
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

        case let .action(.searchQueryChanged(searchQuery)):
            state.searchQuery = searchQuery

        case let .action(.selectedRegionTitleChanged(selectedRegionTitle)):
            state.selectedRegionCode.wrappedValue = regionDetailService.regionCode(by: .regionTitle(selectedRegionTitle)) ?? ""

            return .task(delay: .milliseconds(.init(Floats.dismissDelayMilliseconds))) {
                .isPresentedChanged(false)
            }

        case let .feedback(.isPresentedChanged(isPresented)):
            state.isPresented.wrappedValue = isPresented
        }

        return .none
    }
}
