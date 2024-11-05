//
//  MenuView.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

public final class MenuView: UIView {
    // MARK: - Types

    public struct Style {
        /* MARK: Properties */

        // AnimationParameters
        let appearAnimationParameters: AnimationParameters
        let disappearAnimationParameters: AnimationParameters

        // CGFloat
        let cornerRadius: CGFloat
        let disappearedScalingValue: CGFloat
        let width: CGFloat

        // Other
        let backgroundColor: UIColor
        let element: MenuElementView.Style

        /* MARK: Init */

        public init(
            backgroundColor: UIColor = .white.withAlphaComponent(0.5),
            cornerRadius: CGFloat = 12,
            element: MenuElementView.Style = MenuElementView.Style(),
            width: CGFloat = 250,
            disappearedScalingValue: CGFloat = 0.0001,
            appearAnimationParameters: AnimationParameters = AnimationParameters(),
            disappearAnimationParameters: AnimationParameters = AnimationParameters()
        ) {
            self.backgroundColor = backgroundColor
            self.cornerRadius = cornerRadius
            self.element = element
            self.width = width
            self.disappearedScalingValue = disappearedScalingValue
            self.appearAnimationParameters = appearAnimationParameters
            self.disappearAnimationParameters = disappearAnimationParameters
        }
    }

    // MARK: - Properties

    let anchorPointAlignment: Alignment
    let menu: Menu
    let style: Style

    weak var delegate: MenuViewDelegate?

    // MARK: - Computed Properties

    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // MARK: - Init

    init(
        menu: Menu,
        anchorPointAlignment: Alignment,
        style: Style,
        delegate: MenuViewDelegate?
    ) {
        self.menu = menu
        self.style = style
        self.anchorPointAlignment = anchorPointAlignment
        self.delegate = delegate

        super.init(frame: .zero)

        clipsToBounds = true
        layer.cornerRadius = style.cornerRadius
        backgroundColor = style.backgroundColor

        for (index, child) in menu.children.enumerated() {
            let elementView = MenuElementView(
                element: child,
                style: style.element,
                delegate: self,
                showsDivider: index != menu.children.count - 1
            )
            stackView.addArrangedSubview(elementView)
        }

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.widthAnchor.constraint(equalToConstant: style.width),
            stackView.heightAnchor.constraint(equalToConstant: CGFloat(menu.children.count) * style.element.height),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
