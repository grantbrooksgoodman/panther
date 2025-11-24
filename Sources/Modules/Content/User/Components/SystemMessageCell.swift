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
              let text = message.translation?.output else { return }
        // TODO: Create constants for this.
        label.attributedText = text.sanitized.attributed(.init(
            [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.lightGray,
            ],
            secondaryAttributes: [.init(
                [
                    .font: UIFont.boldSystemFont(ofSize: 12),
                    .foregroundColor: UIColor.lightGray,
                ],
                stringRanges: text.matches(of: /⌘(.*?)⌘/).map { String($0.1) }
            )]
        ))
    }

    func setupSubviews() {
        contentView.addSubview(label)
        label.textAlignment = .center
    }
}
