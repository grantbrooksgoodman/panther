//
//  RegionDetailService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux
import UIKit

public final class RegionDetailService: Cacheable {
    // MARK: - Types

    public enum QueryStrategy {
        case callingCode(String)
        case regionCode(String)
        case regionTitle(String)
        case searchTerm(String)
    }

    public enum RegionTitleFormat {
        case callingCodeFirst
        case regionNameFirst
    }

    // MARK: - Dependencies

    @Dependency(\.currentLocale) private var currentLocale: Locale
    @Dependency(\.commonServices.propertyLists) private var commonPropertyLists: CommonPropertyLists

    // MARK: - Properties

    public let emptyCache: Cache
    public var cache: Cache

    // MARK: - Computed Properties

    public var deviceRegionCode: String { currentLocale.region?.identifier ?? "US" }

    private var callingCodes: [String: String] { commonPropertyLists.callingCodes }
    private var regionTitlesForAllCallingCodes: [String] { getRegionTitlesForAllCallingCodes() }
    private var systemLocalizedLocale: Locale { Locale(languageCode: .init(RuntimeStorage.languageCode)) }

    // MARK: - Init

    public init() {
        emptyCache = .init(
            [
                .localizedRegionNamesForRegionCodes: [String: String](),
                .regionTitlesForAllCallingCodes: [String](),
                .regionTitlesForCallingCodes: [String: (String, RegionTitleFormat)](),
                .regionTitlesForRegionCodes: [String: (String, RegionTitleFormat)](),
            ]
        )
        cache = emptyCache
    }

    // MARK: - Calling Codes

    public func callingCode(regionCode: String) -> String? {
        callingCodes[regionCode.uppercased()]
    }

    // MARK: - Images

    public func image(by strategy: QueryStrategy) -> UIImage? {
        let keys = Array(callingCodes.keys)

        switch strategy {
        case let .regionCode(regionCode):
            var cachedValue = cache.value(forKey: .imagesForRegionCodes) as? [String: UIImage] ?? .init()
            if let image = cachedValue[regionCode] {
                return image
            }

            guard let match = keys.filter({ $0 == regionCode }).first,
                  let image = UIImage(named: "\(match.lowercased()).png") else { return nil }

            cachedValue[regionCode] = image
            cache.set(cachedValue, forKey: .imagesForRegionCodes)

            return image

        case let .regionTitle(regionTitle):
            var cachedValue = cache.value(forKey: .imagesForRegionTitles) as? [String: UIImage] ?? .init()
            if let image = cachedValue[regionTitle] {
                return image
            }

            let format: RegionTitleFormat = regionTitle.hasPrefix("+") ? .callingCodeFirst : .regionNameFirst

            guard let match = keys.filter({ self.regionTitles(by: .regionCode($0), titleFormat: format)?.first == regionTitle }).first,
                  let image = UIImage(named: "\(match.lowercased()).png") else { return nil }

            cachedValue[regionTitle] = image
            cache.set(cachedValue, forKey: .imagesForRegionCodes)

            return image

        case .callingCode,
             .searchTerm:
            return nil
        }
    }

    // MARK: - Region Codes

    public func regionCode(by strategy: QueryStrategy) -> String? {
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

    public func regionCodes(by strategy: QueryStrategy) -> [String]? {
        switch strategy {
        case let .callingCode(callingCode):
            return regionCodes(callingCode: callingCode)

        case let .regionTitle(regionTitle):
            return regionCodes(regionTitle: regionTitle)

        case .regionCode,
             .searchTerm:
            return nil
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

    public func localizedRegionName(regionCode: String) -> String {
        var cachedValue = cache.value(forKey: .localizedRegionNamesForRegionCodes) as? [String: String] ?? .init()
        if let string = cachedValue[regionCode] {
            return string
        }

        func setCacheValue(_ key: String, _ value: String) {
            cachedValue[key] = value
            cache.set(cachedValue, forKey: .localizedRegionNamesForRegionCodes)
        }

        guard callingCodes[regionCode] != nil else { return regionCode }

        guard let regionName = systemLocalizedLocale.localizedString(forRegionCode: regionCode.uppercased()) else {
            setCacheValue(regionCode, Localized(.multiple).wrappedValue)
            return Localized(.multiple).wrappedValue
        }

        setCacheValue(regionCode, regionName)
        return regionName
    }

    public func regionTitles(
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
        if let cachedValue = cache.value(forKey: .regionTitlesForAllCallingCodes) as? [String],
           !cachedValue.isEmpty {
            return cachedValue
        }

        let titles = Array(callingCodes.keys).compactMap { regionTitle(regionCode: $0, titleFormat: .regionNameFirst) }.sorted()
        cache.set(titles, forKey: .regionTitlesForAllCallingCodes)
        return titles
    }

    private func regionTitle(
        callingCode: String,
        titleFormat: RegionTitleFormat
    ) -> String? {
        var cachedValue = cache.value(forKey: .regionTitlesForCallingCodes) as? [String: (String, RegionTitleFormat)] ?? .init()
        if let tuple = cachedValue[callingCode],
           tuple.1 == titleFormat {
            return tuple.0
        }

        func setCacheValue(_ key: String, _ value: String) {
            cachedValue[key] = (value, titleFormat)
            cache.set(cachedValue, forKey: .regionTitlesForCallingCodes)
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
        var cachedValue = cache.value(forKey: .regionTitlesForRegionCodes) as? [String: (String, RegionTitleFormat)] ?? .init()
        if let tuple = cachedValue[regionCode],
           tuple.1 == titleFormat {
            return tuple.0
        }

        func setCacheValue(_ key: String, _ value: String) {
            cachedValue[key] = (value, titleFormat)
            cache.set(cachedValue, forKey: .regionTitlesForRegionCodes)
        }

        guard let callingCode = callingCodes[regionCode] else { return "" }

        func title(for regionName: String) -> String {
            let title: String

            switch titleFormat {
            case .callingCodeFirst:
                title = "+\(callingCode) (\(regionName))"
            case .regionNameFirst:
                title = "\(regionName) (+\(callingCode))"
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

    public func clearCache() {
        CacheDomain.RegionDetailServiceCacheDomainKey.allCases.forEach { cache.removeObject(forKey: .regionDetailService($0)) }
        cache = emptyCache
    }
}

/* MARK: Cache */

public extension CacheDomain {
    enum RegionDetailServiceCacheDomainKey: String, CaseIterable, Equatable {
        case imagesForRegionCodes
        case imagesForRegionTitles

        case localizedRegionNamesForRegionCodes

        case regionTitlesForAllCallingCodes
        case regionTitlesForCallingCodes
        case regionTitlesForRegionCodes
    }
}

public extension Cache {
    convenience init(_ objects: [CacheDomain.RegionDetailServiceCacheDomainKey: Any]) {
        var mappedObjects = [CacheDomain: Any]()
        objects.forEach { object in
            mappedObjects[.regionDetailService(object.key)] = object.value
        }
        self.init(mappedObjects)
    }

    func set(_ value: Any, forKey key: CacheDomain.RegionDetailServiceCacheDomainKey) {
        set(value, forKey: .regionDetailService(key))
    }

    func value(forKey key: CacheDomain.RegionDetailServiceCacheDomainKey) -> Any? {
        value(forKey: .regionDetailService(key))
    }
}
