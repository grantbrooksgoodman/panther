//
//  MenuElementView.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

public final class MenuElementView: UIView {
    // MARK: - Properties

    let element: MenuElement
    let style: Style

    weak var delegate: MenuElementViewDelegate?

    // MARK: - Computed Properties

    lazy var button: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(onButtonTouchedUpInside), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = element.image?.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = MenuElementView.iconTint(attributes: element.attributes, style: style)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    lazy var label: UILabel = {
        let label = UILabel()
        label.attributedText = .init(
            string: element.title,
            attributes: MenuElementView.titleAttributes(
                attributes: element.attributes,
                style: style
            )
        )
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var dividerView: UIView = {
        let dividerView = UIView()
        dividerView.backgroundColor = .systemGray2
        dividerView.translatesAutoresizingMaskIntoConstraints = false
        return dividerView
    }()

    // MARK: - Init

    init(
        element: MenuElement,
        style: Style,
        delegate: MenuElementViewDelegate?
    ) {
        self.element = element
        self.style = style
        self.delegate = delegate

        super.init(frame: .zero)

        addSubview(button)
        addSubview(label)
        addSubview(imageView)
        addSubview(dividerView)

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: topAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(equalToSystemSpacingAfter: leadingAnchor, multiplier: 1),
            trailingAnchor.constraint(equalToSystemSpacingAfter: imageView.trailingAnchor, multiplier: 1),
            imageView.leadingAnchor.constraint(equalToSystemSpacingAfter: label.trailingAnchor, multiplier: 1),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: element.image == nil ? 0 : style.iconSize.width),
            imageView.heightAnchor.constraint(equalToConstant: style.iconSize.height),
            dividerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dividerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dividerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            dividerView.heightAnchor.constraint(equalToConstant: 0.6),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Auxiliary

    @objc
    func onButtonTouchedUpInside(_ sender: Any?) {
        delegate?.menuElementViewTapped(menuElementView: self)
    }
}
