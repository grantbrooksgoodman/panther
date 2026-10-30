//
//  LanguageModelLoggerDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 28/10/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import LanguageModels

struct LanguageModelLoggerDelegate: LanguageModelLogDelegate {
    func log(_ entry: LanguageModelLogEntry) {
        if let error = entry.error {
            return Logger.log(
                Exception(
                    error,
                    userInfo: [
                        "Category": entry.category,
                        "Message": entry.message,
                    ],
                    metadata: .init(
                        sender: self,
                        fileName: entry.fileName,
                        function: entry.function,
                        line: entry.line
                    )
                ),
                domain: .languageModels,
                with: entry.showsToast ? .toast(style: .error) : nil
            )
        } else if entry.level == .error {
            return Logger.log(
                Exception(
                    entry.message,
                    userInfo: ["Category": entry.category],
                    metadata: .init(
                        sender: self,
                        fileName: entry.fileName,
                        function: entry.function,
                        line: entry.line
                    )
                ),
                domain: .languageModels,
                with: entry.showsToast ? .toast(style: .error) : nil
            )
        }

        Logger.log(
            "[\(entry.level.rawValue.uppercased()) | \(entry.category)] \(entry.message)",
            domain: .languageModels,
            with: entry.showsToast ? .toast : nil,
            sender: self,
            fileName: entry.fileName,
            function: entry.function,
            line: entry.line
        )
    }
}

extension LanguageModelLogEntry.Level: @retroactive RawRepresentable {
    // MARK: - Properties

    public var rawValue: String {
        switch self {
        case .debug: "debug"
        case .error: "error"
        case .info: "info"
        }
    }

    // MARK: - Init

    public init?(rawValue: String) {
        switch rawValue {
        case "debug": self = .debug
        case "error": self = .error
        case "info": self = .info
        default: return nil
        }
    }
}

extension LanguageModels {
    static let showsToastsForLogEntryLevel = LockIsolated<LanguageModelLogEntry.Level?>(nil)
}

private extension LanguageModelLogEntry {
    var showsToast: Bool {
        @Dependency(\.build.milestone) var buildMilestone: Build.Milestone
        guard buildMilestone != .generalRelease else { return false }
        return level == LanguageModels.showsToastsForLogEntryLevel.wrappedValue
    }
}
