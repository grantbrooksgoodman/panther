//
//  SystemInformation.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

// swiftlint:disable line_length
/// A namespace for low-level hardware and kernel values queried through `sysctl`.
///
/// Use ``SystemInformation`` to read details about the device and operating system. Each
/// property returns a fallback value – `"Unknown"` or zero – when the underlying query fails.
enum SystemInformation {
    // MARK: - Types

    private enum SystemInformationError: Error {
        case invalidSize
        case malformedUtf8
        case posixError(POSIXErrorCode)
        case unknownError
    }

    // MARK: - Properties

    /// The number of CPUs available on the device, or zero if the query fails.
    static var activeCPUs: Int64 {
        (try? informationInteger(withLevels: CTL_HW, HW_AVAILCPU)) ?? .zero
    }

    /// The device's host name, or `"Unknown"` if the query fails.
    static var deviceName: String {
        (try? informationString(withLevels: CTL_KERN, KERN_HOSTNAME)) ?? "Unknown"
    }

    /// The kernel's version string, or `"Unknown"` if the query fails.
    static var kernelVersion: String {
        (try? informationString(withLevels: CTL_KERN, KERN_VERSION)) ?? "Unknown"
    }

    /// The device's hardware model code, as reported by the kernel, or `"Unknown"` if the query
    /// fails.
    ///
    /// - Note: The underlying query differs between device and simulator builds.
    static var modelCode: String {
        #if os(iOS) && !arch(x86_64) && !arch(i386)
        return (try? informationString(withLevels: CTL_HW, HW_MODEL)) ?? "Unknown"
        #else
        return (try? informationString(withLevels: CTL_HW, HW_MACHINE)) ?? "Unknown"
        #endif
    }

    /// The device's hardware model name, as reported by the kernel, or `"Unknown"` if the query
    /// fails.
    ///
    /// - Note: The underlying query differs between device and simulator builds.
    static var modelName: String {
        #if os(iOS) && !arch(x86_64) && !arch(i386)
        return (try? informationString(withLevels: CTL_HW, HW_MACHINE)) ?? "Unknown"
        #else
        return (try? informationString(withLevels: CTL_HW, HW_MODEL)) ?? "Unknown"
        #endif
    }

    /// The operating system's release string, or `"Unknown"` if the query fails.
    static var osRelease: String {
        (try? informationString(withLevels: CTL_KERN, KERN_OSRELEASE)) ?? "Unknown"
    }

    /// The operating system's revision number, or zero if the query fails.
    static var osRevision: Int64 {
        (try? informationInteger(withLevels: CTL_KERN, KERN_OSREV)) ?? .zero
    }

    /// The operating system's type string, or `"Unknown"` if the query fails.
    static var osType: String {
        (try? informationString(withLevels: CTL_KERN, KERN_OSTYPE)) ?? "Unknown"
    }

    /// The operating system's build version string, or `"Unknown"` if the query fails.
    static var osVersion: String {
        (try? informationString(withLevels: CTL_KERN, KERN_OSVERSION)) ?? "Unknown"
    }

    // MARK: - Auxiliary

    private static func getInformation(fromLevelName: String) throws -> [Int32] {
        var levelBufferSize = Int(CTL_MAXNAME)

        var levelBuffer = [Int32](repeating: 0, count: levelBufferSize)

        try levelBuffer.withUnsafeMutableBufferPointer { (levelBufferPointer: inout UnsafeMutableBufferPointer<Int32>) throws in
            try fromLevelName.withCString { (nameBufferPointer: UnsafePointer<Int8>) throws in
                guard sysctlnametomib(nameBufferPointer, levelBufferPointer.baseAddress, &levelBufferSize) == 0 else {
                    throw POSIXErrorCode(rawValue: errno).map { SystemInformationError.posixError($0) } ?? SystemInformationError.unknownError
                }
            }
        }

        if levelBuffer.count > levelBufferSize {
            levelBuffer.removeSubrange(levelBufferSize ..< levelBuffer.count)
        }

        return levelBuffer
    }

    private static func getInformation(withLevels: [Int32]) throws -> [Int8] {
        try withLevels.withUnsafeBufferPointer { levelsPointer throws -> [Int8] in
            var requiredSize = 0

            let preFlightResult = Darwin.sysctl(UnsafeMutablePointer<Int32>(mutating: levelsPointer.baseAddress), UInt32(withLevels.count), nil, &requiredSize, nil, 0)

            if preFlightResult != 0 {
                throw POSIXErrorCode(rawValue: errno).map { SystemInformationError.posixError($0) } ?? SystemInformationError.unknownError
            }

            let arrayBufferData = [Int8](repeating: 0, count: requiredSize)

            let representedResult = arrayBufferData.withUnsafeBufferPointer { dataBuffer -> Int32 in
                Darwin.sysctl(UnsafeMutablePointer<Int32>(mutating: levelsPointer.baseAddress), UInt32(withLevels.count), UnsafeMutableRawPointer(mutating: dataBuffer.baseAddress), &requiredSize, nil, 0)
            }

            if representedResult != 0 {
                throw POSIXErrorCode(rawValue: errno).map { SystemInformationError.posixError($0) } ?? SystemInformationError.unknownError
            }

            return arrayBufferData
        }
    }

    private static func informationInteger(withLevels: Int32...) throws -> Int64 {
        try integerFromSystemInformation(withLevels: withLevels)
    }

    private static func informationInteger(withName: String) throws -> Int64 {
        try integerFromSystemInformation(withLevels: getInformation(fromLevelName: withName))
    }

    private static func informationString(withLevels: Int32...) throws -> String {
        try stringFromSystemInformation(withLevels: withLevels)
    }

    private static func informationString(withName: String) throws -> String {
        try stringFromSystemInformation(withLevels: getInformation(fromLevelName: withName))
    }

    private static func integerFromSystemInformation(withLevels: [Int32]) throws -> Int64 {
        let informationBuffer = try getInformation(withLevels: withLevels)

        switch informationBuffer.count {
        case 4: return informationBuffer.withUnsafeBufferPointer { $0.baseAddress.map { $0.withMemoryRebound(to: Int32.self, capacity: 1) { Int64($0.pointee) }} ?? 0 }

        case 8: return informationBuffer.withUnsafeBufferPointer { $0.baseAddress.map { $0.withMemoryRebound(to: Int64.self, capacity: 1) { $0.pointee }} ?? 0 }

        default: throw SystemInformationError.invalidSize
        }
    }

    private static func stringFromSystemInformation(withLevels: [Int32]) throws -> String {
        let optionalString = try getInformation(withLevels: withLevels).withUnsafeBufferPointer { dataPointer -> String? in
            dataPointer.baseAddress.flatMap { String(validatingCString: $0) }
        }

        guard let returnedString = optionalString else {
            throw SystemInformationError.malformedUtf8
        }

        return returnedString
    }
}

// swiftlint:enable line_length
