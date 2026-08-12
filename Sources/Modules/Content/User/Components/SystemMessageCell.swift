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

/// A collection view cell that displays a system message.
///
/// Use ``SystemMessageCell`` in the chat page's message list to show centered, bubble-less
/// text scaled to fit the cell's width.
final class SystemMessageCell: UICollectionViewCell {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.SystemMessageCell

    // MARK: - Properties

    private let label = UILabel()

    private var attributedString: NSAttributedString?

    // MARK: - Init

    /// Creates a system message cell with the given frame.
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(label)
    }

    /// Creates a system message cell from the given decoder.
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        contentView.addSubview(label)
    }

    // MARK: - Methods

    /// Lays out the label to fill the cell and rescales its text to fit.
    override func layoutSubviews() {
        super.layoutSubviews()

        defer { setLabelProperties() }
        label.frame = contentView.bounds

        guard let attributedString else { return }
        label.attributedText = attributedString.scaledToFit(
            width: label.bounds.width
        )
    }

    /// Configures the cell with the given message's system string.
    ///
    /// - Parameters:
    ///   - message: The message whose system string to display.
    ///   - indexPath: The index path of the cell.
    ///   - messagesCollectionView: The collection view containing the cell.
    func configure(
        with message: MessageType,
        at indexPath: IndexPath,
        and messagesCollectionView: MessagesCollectionView
    ) {
        attributedString = (message as? Message)?.attributedSystemString
        setNeedsLayout()
    }

    private func setLabelProperties() {
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = Int(Floats.labelNumberOfLines)
        label.textAlignment = .center
    }
}

private extension NSAttributedString {
    func scaledToFit(
        font: UIFont = .systemFont(ofSize: AppConstants.CGFloats.SystemMessageCell.activityStringSystemFontSize),
        lineSpacing: CGFloat = AppConstants.CGFloats.SystemMessageCell.labelParagraphStyleLineSpacing,
        minimumScaleFactor: CGFloat = AppConstants.CGFloats.SystemMessageCell.labelMinimumScaleFactor,
        maximumScaleFactor: CGFloat = 1,
        numberOfLines: Int = Int(AppConstants.CGFloats.SystemMessageCell.labelNumberOfLines),
        width: CGFloat
    ) -> NSAttributedString {
        guard numberOfLines > 0,
              width > 0 else { return self }

        let boundingRectangle = boundingRect(
            with: .init(
                width: width,
                height: .greatestFiniteMagnitude
            ),
            options: [.usesFontLeading, .usesLineFragmentOrigin],
            context: nil
        )

        guard boundingRectangle.height > 0 else { return self }

        let maximumTextHeight = CGFloat(numberOfLines) * (font.lineHeight + lineSpacing)
        let heightScale = maximumTextHeight / boundingRectangle.height
        let widthScale = width / max(boundingRectangle.width, 1)

        var scale = min(heightScale, widthScale, maximumScaleFactor)
        scale *= 0.98 // Safety margin so we don't land exactly on the truncation edge

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
