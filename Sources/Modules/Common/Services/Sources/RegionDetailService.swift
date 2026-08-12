//
//  RegionDetailService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/// Use ``RegionDetailService`` to look up region details – names, titles, calling codes, and
/// images – for the regions in the app's phone number reference data.
///
/// Lookup results are cached in memory.
final class RegionDetailService {
    // MARK: - Types

    /// A criterion for querying region details.
    ///
    /// Each query method supports a subset of strategies; unsupported strategies return `nil`.
    enum QueryStrategy {
        /// Queries by international calling code.
        case callingCode(String)

        /// Queries by region code.
        case regionCode(String)

        /// Queries by formatted region title.
        case regionTitle(String)

        /// Queries by free-form search term.
        case searchTerm(String)
    }

    /// The arrangement of a region title's components.
    ///
    /// A region title combines a region's name with its calling code – for example,
    /// `+1 (United States)` or `United States (+1)`.
    enum RegionTitleFormat {
        /// Places the calling code before the region name.
        case callingCodeFirst

        /// Places the region name before the calling code.
        case regionNameFirst
    }

    private enum CacheKey: String, CaseIterable {
        case imagesForRegionCodes
        case imagesForRegionTitles

        case localizedRegionNamesForRegionCodes

        case regionTitlesForAllCallingCodes
        case regionTitlesForCallingCodes
        case regionTitlesForRegionCodes
    }

    // MARK: - Dependencies

    @Dependency(\.currentLocale) private var currentLocale: Locale
    @Dependency(\.commonServices.propertyLists) private var commonPropertyLists: CommonPropertyLists

    // MARK: - Properties

    @Cached(CacheKey.imagesForRegionCodes) private var cachedImagesForRegionCodes: [String: UIImage]?
    @Cached(CacheKey.imagesForRegionTitles) private var cachedImagesForRegionTitles: [String: UIImage]?
    @Cached(CacheKey.localizedRegionNamesForRegionCodes) private var cachedLocalizedRegionNamesForRegionCodes: [String: String]?
    @Cached(CacheKey.regionTitlesForAllCallingCodes) private var cachedRegionTitlesForAllCallingCodes: [String]?
    @Cached(CacheKey.regionTitlesForCallingCodes) private var cachedRegionTitlesForCallingCodes: [String: (String, RegionTitleFormat)]?
    @Cached(CacheKey.regionTitlesForRegionCodes) private var cachedRegionTitlesForRegionCodes: [String: (String, RegionTitleFormat)]?

    // MARK: - Computed Properties

    /// The region code for the device's current region, or `US` if it cannot be determined.
    var deviceRegionCode: String {
        currentLocale.region?.identifier ?? "US"
    }

    private var callingCodes: [String: String] {
        commonPropertyLists.callingCodes
    }

    private var regionTitlesForAllCallingCodes: [String] {
        getRegionTitlesForAllCallingCodes()
    }

    private var systemLocalizedLocale: Locale {
        Locale(languageCode: .init(RuntimeStorage.languageCode))
    }

    // MARK: - Calling Codes

    /// Returns the international calling code for the given region code.
    ///
    /// - Parameter regionCode: The region code to look up.
    ///
    /// - Returns: The region's calling code; otherwise, `nil` if the region code is unknown.
    func callingCode(regionCode: String) -> String? {
        callingCodes[regionCode.uppercased()]
    }

    // MARK: - Images

    /// Returns the image for the region matching the given strategy.
    ///
    /// Supported strategies are ``QueryStrategy/regionCode(_:)`` and
    /// ``QueryStrategy/regionTitle(_:)``.
    ///
    /// - Parameter strategy: The criterion by which to find the region.
    ///
    /// - Returns: The region's image; otherwise, `nil` if no match exists or the strategy is
    ///   unsupported.
    func image(by strategy: QueryStrategy) -> UIImage? {
        let keys = Array(callingCodes.keys)

        switch strategy {
        case let .regionCode(regionCode):
            var cachedValue = cachedImagesForRegionCodes ?? .init()
            if let image = cachedValue[regionCode] {
                return image
            }

            guard let match = keys.filter({ $0 == regionCode }).first,
                  let image = UIImage(named: "\(match.lowercased()).png") else { return nil }

            cachedValue[regionCode] = image
            cachedImagesForRegionCodes = cachedValue
            return image

        case let .regionTitle(regionTitle):
            var cachedValue = cachedImagesForRegionTitles ?? .init()
            if let image = cachedValue[regionTitle] {
                return image
            }

            let format: RegionTitleFormat = regionTitle.hasPrefix("+") ? .callingCodeFirst : .regionNameFirst

            guard let match = keys.filter({ self.regionTitles(by: .regionCode($0), titleFormat: format)?.first == regionTitle }).first,
                  let image = UIImage(named: "\(match.lowercased()).png") else { return nil }

            cachedValue[regionTitle] = image
            cachedImagesForRegionTitles = cachedValue

            return image

        case .callingCode,
             .searchTerm:
            return nil
        }
    }

    // MARK: - Region Codes

    /// Returns the region code matching the given strategy.
    ///
    /// Supported strategies are ``QueryStrategy/callingCode(_:)`` and
    /// ``QueryStrategy/regionTitle(_:)``. When multiple regions share the given calling code, a
    /// localized "Multiple" placeholder is returned.
    ///
    /// - Parameter strategy: The criterion by which to find the region code.
    ///
    /// - Returns: The matching region code; otherwise, `nil` if no match exists or the
    ///   strategy is unsupported.
    func regionCode(by strategy: QueryStrategy) -> String? {
        switch strategy {
        case let .callingCode(callingCode):
            guard let regionCodes = regionCodes(callingCode: callingCode) else { return nil }
            guard regionCodes.count == 1 else { return Localized(.multiple).wrappedValue }
            return regionCodes[0]

        case let .regionTitle(regionTitle):
            return regionCodes(regionTitle: regionTitle)?.first

        case .regionCode,
             .searchTerm:
            return nil
        }
    }

    /// Returns every region code matching the given strategy.
    ///
    /// Supported strategies are ``QueryStrategy/callingCode(_:)`` and
    /// ``QueryStrategy/regionTitle(_:)``.
    ///
    /// - Parameter strategy: The criterion by which to find the region codes.
    ///
    /// - Returns: The matching region codes; otherwise, `nil` if no match exists or the
    ///   strategy is unsupported.
    func regionCodes(by strategy: QueryStrategy) -> [String]? {
        switch strategy {
        case let .callingCode(callingCode):
            regionCodes(callingCode: callingCode)

        case let .regionTitle(regionTitle):
            regionCodes(regionTitle: regionTitle)

        case .regionCode,
             .searchTerm:
            nil
        }
    }

    private func regionCodes(callingCode: String) -> [String]? {
        guard Array(callingCodes.values).contains(callingCode) else { return nil }
        return callingCodes.keys(for: callingCode)
    }

    private func regionCodes(regionTitle title: String) -> [String]? {
        let format: RegionTitleFormat = title.hasPrefix("+") ? .callingCodeFirst : .regionNameFirst
        return Array(callingCodes.keys).filter { regionTitles(by: .regionCode($0), titleFormat: format)?.first == title }
    }

    // MARK: - Region Titles

    /// Returns the localized display name for the given region code.
    ///
    /// - Parameters:
    ///   - regionCode: The region code whose name to resolve.
    ///   - languageCode: The language code in which to localize the name. Pass `nil` to use
    ///     the system language; results localized to the system language are cached in memory.
    ///     The default is `nil`.
    ///
    /// - Returns: The localized region name. If the region code is unknown, it is returned
    ///   unchanged; if no localized name exists, a localized "Multiple" placeholder is
    ///   returned.
    func localizedRegionName(
        regionCode: String,
        languageCode: String? = nil
    ) -> String {
        var cachedValue = cachedLocalizedRegionNamesForRegionCodes ?? .init()
        if let string = cachedValue[regionCode],
           languageCode == nil {
            return string
        }

        func setCacheValue(
            _ key: String,
            _ value: String
        ) {
            guard languageCode == nil else { return }
            cachedValue[key] = value
            cachedLocalizedRegionNamesForRegionCodes = cachedValue
        }

        guard callingCodes[regionCode] != nil else { return regionCode }

        let locale = languageCode == nil ? systemLocalizedLocale : Locale(languageCode: .init(languageCode!))
        guard let regionName = locale.localizedString(forRegionCode: regionCode.uppercased()) else {
            setCacheValue(regionCode, Localized(.multiple).wrappedValue)
            return Localized(.multiple).wrappedValue
        }

        setCacheValue(regionCode, regionName)
        return regionName
    }

    /// Returns the region titles matching the given strategy.
    ///
    /// Supported strategies are ``QueryStrategy/callingCode(_:)``,
    /// ``QueryStrategy/regionCode(_:)``, and ``QueryStrategy/searchTerm(_:)`` – a blank search
    /// term matches every region title.
    ///
    /// - Parameters:
    ///   - strategy: The criterion by which to find the region titles.
    ///   - titleFormat: The arrangement of each title's components. The default is
    ///     ``RegionTitleFormat/callingCodeFirst``.
    ///
    /// - Returns: The matching region titles; otherwise, `nil` if no match exists or the
    ///   strategy is unsupported.
    func regionTitles(
        by strategy: QueryStrategy,
        titleFormat: RegionTitleFormat = .callingCodeFirst
    ) -> [String]? {
        switch strategy {
        case let .callingCode(callingCode):
            let regionTitle = regionTitle(callingCode: callingCode, titleFormat: titleFormat)
            return regionTitle == nil ? nil : [regionTitle!]

        case let .regionCode(regionCode):
            let regionTitle = regionTitle(regionCode: regionCode, titleFormat: titleFormat)
            return regionTitle == nil ? nil : [regionTitle!]

        case let .searchTerm(searchTerm):
            guard !searchTerm.isBlank else { return regionTitlesForAllCallingCodes }
            let filtered = regionTitlesForAllCallingCodes.filter {
                $0.lowercasedTrimmingWhitespaceAndNewlines.contains(searchTerm.lowercasedTrimmingWhitespaceAndNewlines)
            }
            return filtered.isEmpty ? nil : filtered

        case .regionTitle:
            return nil
        }
    }

    private func getRegionTitlesForAllCallingCodes() -> [String] {
        if let cachedValue = cachedRegionTitlesForAllCallingCodes,
           !cachedValue.isEmpty {
            return cachedValue
        }

        let titles = Array(callingCodes.keys).compactMap { regionTitle(regionCode: $0, titleFormat: .regionNameFirst) }.sorted()
        cachedRegionTitlesForAllCallingCodes = titles
        return titles
    }

    private func regionTitle(
        callingCode: String,
        titleFormat: RegionTitleFormat
    ) -> String? {
        var cachedValue = cachedRegionTitlesForCallingCodes ?? .init()
        if let tuple = cachedValue[callingCode],
           tuple.1 == titleFormat {
            return tuple.0
        }

        func setCacheValue(
            _ key: String,
            _ value: String
        ) {
            cachedValue[key] = (value, titleFormat)
            cachedRegionTitlesForCallingCodes = cachedValue
        }

        guard Array(callingCodes.values).contains(callingCode) else { return nil }
        let regions = callingCodes.keys(for: callingCode)

        guard regions.count == 1 else {
            let title = "+\(callingCode) (Multiple)"
            setCacheValue(callingCode, title)
            return title
        }

        if let title = regionTitles(by: .regionCode(regions[0]), titleFormat: titleFormat)?.first {
            setCacheValue(callingCode, title)
            return title
        }

        return nil
    }

    private func regionTitle(
        regionCode: String,
        titleFormat: RegionTitleFormat
    ) -> String? {
        var cachedValue = cachedRegionTitlesForRegionCodes ?? .init()
        if let tuple = cachedValue[regionCode],
           tuple.1 == titleFormat {
            return tuple.0
        }

        func setCacheValue(
            _ key: String,
            _ value: String
        ) {
            cachedValue[key] = (value, titleFormat)
            cachedRegionTitlesForRegionCodes = cachedValue
        }

        guard let callingCode = callingCodes[regionCode] else { return "" }

        func title(for regionName: String) -> String {
            let title = switch titleFormat {
            case .callingCodeFirst:
                "+\(callingCode) (\(regionName))"
            case .regionNameFirst:
                "\(regionName) (+\(callingCode))"
            }

            setCacheValue(regionCode, title)
            return title
        }

        guard let regionName = systemLocalizedLocale.localizedString(forRegionCode: regionCode) else {
            return title(for: Localized(.multiple).wrappedValue)
        }

        return title(for: regionName)
    }

    // MARK: - Clear Cache

    /// Removes every cached lookup result.
    func clearCache() {
        cachedImagesForRegionCodes = nil
        cachedImagesForRegionTitles = nil

        cachedLocalizedRegionNamesForRegionCodes = nil

        cachedRegionTitlesForAllCallingCodes = nil
        cachedRegionTitlesForCallingCodes = nil
        cachedRegionTitlesForRegionCodes = nil
    }
}
