//
//  Date+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

public extension Date { // swiftlint:disable:next identifier_name
    var chatPageMessageSeparatorAttributedDateString: NSAttributedString? {
        typealias Floats = AppConstants.CGFloats.UserContentExtensions.Date

        func attributedForChatPageMessageSeparator(_ string: String, separatorIndex: Int) -> NSAttributedString {
            let attributed = NSMutableAttributedString(string: string)

            typealias Colors = AppConstants.Colors.UserContentExtensions.Date
            typealias Key = NSAttributedString.Key

            let boldAttributes: [Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: Floats.chatPageMessageSeparatorAttributedDateStringBoldAttributesSystemFontSize),
                .foregroundColor: UIColor(Colors.chatPageMessageSeparatorAttributedDateStringBoldAttributesForeground),
            ]

            let standardAttributes: [Key: Any] = [
                .font: UIFont.systemFont(ofSize: Floats.chatPageMessageSeparatorAttributedDateStringStandardAttributesSystemFontSize),
                .foregroundColor: UIColor(Colors.chatPageMessageSeparatorAttributedDateStringStandardAttributesForeground),
            ]

            let boldAttributeRange = NSRange(location: 0, length: separatorIndex)
            let standardAttributeRange = NSRange(location: separatorIndex, length: attributed.length - separatorIndex)

            attributed.addAttributes(boldAttributes, range: boldAttributeRange)
            attributed.addAttributes(standardAttributes, range: standardAttributeRange)

            return attributed
        }

        @Dependency(\.currentCalendar) var calendar: Calendar

        let distance = calendar.startOfDay(for: Date.now).distance(to: calendar.startOfDay(for: self))
        let timeString = DateFormatter.localizedString(from: self, dateStyle: .none, timeStyle: .short)

        let overYearFormatter = DateFormatter()
        overYearFormatter.locale = Locale(identifier: RuntimeStorage.languageCode)
        overYearFormatter.dateFormat = Locale.systemLanguageID == "en-US" ? "MMM dd yyyy," : "dd MMM yyyy,"

        let underYearFormatter = DateFormatter()
        underYearFormatter.locale = Locale(identifier: RuntimeStorage.languageCode)
        underYearFormatter.dateFormat = Locale.systemLanguageID == "en-US" ? "E MMM d," : "E d MMM,"

        let overYearString = overYearFormatter.string(from: self)
        let underYearString = underYearFormatter.string(from: self)

        guard let overYearStringSeparatorIndex = overYearString.components(separatedBy: ",").first?.count,
              let underYearStringSeparatorIndex = underYearString.components(separatedBy: ",").first?.count else { return nil }

        if distance == 0 {
            @Localized(.today) var separator: String
            let string = "\(separator) \(timeString)"
            return attributedForChatPageMessageSeparator(string, separatorIndex: separator.count)
        } else if distance == Floats.chatPageMessageSeparatorAttributedDateStringYesterdayComparator {
            @Localized(.yesterday) var separator: String
            let string = "\(separator) \(timeString)"
            return attributedForChatPageMessageSeparator(string, separatorIndex: separator.count)
        } else if distance >= Floats.chatPageMessageSeparatorAttributedDateStringWeekdayComparator {
            let weekdayString = weekdayString()
            let currentWeekdayString = Date.now.weekdayString()

            guard weekdayString == currentWeekdayString else {
                let string = "\(weekdayString) \(timeString)"
                return attributedForChatPageMessageSeparator(string, separatorIndex: weekdayString.count)
            }

            let string = "\(underYearString) \(timeString)"
            return attributedForChatPageMessageSeparator(string, separatorIndex: underYearStringSeparatorIndex + 1)
        } else if distance < Floats.chatPageMessageSeparatorAttributedDateStringUnderYearPrimaryComparator,
                  distance > Floats.chatPageMessageSeparatorAttributedDateStringUnderYearSecondaryComparator {
            let string = "\(underYearString) \(timeString)"
            return attributedForChatPageMessageSeparator(string, separatorIndex: underYearStringSeparatorIndex + 1)
        }

        let string = "\(overYearString) \(timeString)"
        return attributedForChatPageMessageSeparator(string, separatorIndex: overYearStringSeparatorIndex + 1)
    }
}
