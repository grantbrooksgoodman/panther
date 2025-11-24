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
        guard let message = message as? Message else { return }
        label.text = message.translation?.output
    }

    func setupSubviews() {
        contentView.addSubview(label)
        label.textAlignment = .center
        label.font = UIFont.italicSystemFont(ofSize: 13)
    }
}
