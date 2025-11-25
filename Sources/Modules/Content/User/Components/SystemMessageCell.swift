//
//  SystemMessageCell.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/11/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import MessageKit

public final class SystemMessageCell: UICollectionViewCell {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.SystemMessageCell
    private typealias Floats = AppConstants.CGFloats.SystemMessageCell

    // MARK: - Properties

    private let label = UILabel()

    // MARK: - Init

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupSubviews()
    }

    // MARK: - Methods

    override public func layoutSubviews() {
        super.layoutSubviews()
        label.frame = contentView.bounds
    }

    func configure(
        with message: MessageType,
        at indexPath: IndexPath,
        and messagesCollectionView: MessagesCollectionView
    ) {
        guard let message = message as? Message,
              let text = message.translation?.output,
              let dateString = message.sentDate.chatPageMessageSeparatorAttributedDateString else { return }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = Floats.labelParagraphStyleLineSpacing

        let mutableDateString = NSMutableAttributedString(attributedString: dateString)
        mutableDateString.addAttributes(
            [.paragraphStyle: paragraphStyle],
            range: .init(
                location: 0,
                length: mutableDateString.length
            )
        )

        let activityString = text.sanitized.attributed(.init(
            [
                .font: UIFont.systemFont(ofSize: Floats.activityStringSystemFontSize),
                .foregroundColor: Colors.activityStringForeground,
            ],
            secondaryAttributes: [.init(
                [
                    .font: UIFont.boldSystemFont(ofSize: Floats.activityStringSystemFontSize),
                    .foregroundColor: Colors.activityStringForeground,
                ],
                stringRanges: text.matches(of: /⌘(.*?)⌘/).map { String($0.1) }
            )]
        ))

        let combinedString = NSMutableAttributedString(attributedString: mutableDateString)
        combinedString.append(NSAttributedString(string: "\n"))
        combinedString.append(activityString)

        label.attributedText = combinedString.scaledToFit(
            label.bounds.size,
            minimumScaleFactor: Floats.labelMinimumScaleFactor
        )

        label.numberOfLines = Int(Floats.labelNumberOfLines)
        label.textAlignment = .center
    }

    private func setupSubviews() {
        contentView.addSubview(label)
        label.textAlignment = .center
    }
}

private extension NSAttributedString {
    func scaledToFit(
        _ targetSize: CGSize,
        minimumScaleFactor: CGFloat = 0.5,
        maximumScaleFactor: CGFloat = 1.0
    ) -> NSAttributedString {
        guard targetSize.height > 0,
              targetSize.width > 0 else { return self }

        let boundingRectangle = boundingRect(
            with: .init(
                width: targetSize.width,
                height: .greatestFiniteMagnitude
            ),
            options: [
                .usesFontLeading,
                .usesLineFragmentOrigin,
            ],
            context: nil
        )

        guard boundingRectangle.height > 0,
              boundingRectangle.width > 0 else { return self }

        let heightScale = targetSize.height / boundingRectangle.height
        let widthScale = targetSize.width / boundingRectangle.width

        var scale = min(
            heightScale,
            widthScale,
            maximumScaleFactor
        )

        scale = max(scale, minimumScaleFactor)
        guard abs(scale - 1.0) >= 0.01 else { return self }

        let scaledString = NSMutableAttributedString(attributedString: self)
        scaledString.enumerateAttribute(
            .font,
            in: .init(location: 0, length: length),
            options: []
        ) { value, range, _ in
            guard let font = value as? UIFont else { return }
            scaledString.addAttribute(
                .font,
                value: font.withSize(font.pointSize * scale),
                range: range
            )
        }

        return scaledString
    }
}
