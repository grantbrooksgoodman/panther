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

/* Proprietary */
import AppSubsystem

final class MenuView: UIView {
    // MARK: - Types

    struct Style {
        /* MARK: Properties */

        let appearAnimationParameters: AnimationParameters
        let backgroundColor: UIColor
        let cornerRadius: CGFloat
        let disappearAnimationParameters: AnimationParameters
        let disappearedScalingValue: CGFloat
        let element: MenuElementView.Style
        let width: CGFloat

        /* MARK: Init */

        init(
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

    // MARK: - Dependencies

    @Dependency(\.commonServices.haptics) private var hapticsService: HapticsService

    // MARK: - Properties

    let anchorPointAlignment: Alignment
    let menu: Menu
    let style: Style

    weak var delegate: MenuViewDelegate?

    private(set) var dragGesture: UILongPressGestureRecognizer?

    private var highlightedElementIndex: Int?

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

        let gesture = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleDragGesture(_:))
        )

        gesture.allowableMovement = .greatestFiniteMagnitude
        gesture.isEnabled = false
        gesture.minimumPressDuration = 0
        addGestureRecognizer(gesture)

        dragGesture = gesture
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Methods

    func element(at point: CGPoint) -> MenuElement? {
        for case let elementView as MenuElementView in stackView.arrangedSubviews {
            let pointInElement = elementView.convert(
                point,
                from: self
            )

            if elementView.bounds.contains(pointInElement) {
                return elementView.element
            }
        }

        return nil
    }

    func highlightElement(at point: CGPoint) {
        var newHighlightedIndex: Int?

        for (index, view) in stackView.arrangedSubviews.enumerated() {
            guard let elementView = view as? MenuElementView else { continue }
            let pointInElement = elementView.convert(
                point,
                from: self
            )

            let isHighlighted = elementView.bounds.contains(pointInElement)
            elementView.setHighlighted(isHighlighted)

            if isHighlighted { newHighlightedIndex = index }
        }

        if newHighlightedIndex != highlightedElementIndex {
            if highlightedElementIndex != nil,
               newHighlightedIndex != nil {
                hapticsService.generateFeedback(.selection)
            }

            highlightedElementIndex = newHighlightedIndex
        }
    }

    func unhighlightAllElements() {
        highlightedElementIndex = nil
        for case let elementView as MenuElementView in stackView.arrangedSubviews {
            elementView.setHighlighted(false)
        }
    }

    // MARK: - Auxiliary

    @objc
    private func handleDragGesture(_ sender: UIGestureRecognizer) {
        let location = sender.location(in: self)
        switch sender.state {
        case .began,
             .changed:
            highlightElement(at: location)

        case .ended:
            if let element = element(at: location) {
                unhighlightAllElements()
                delegate?.dismissMenuView(
                    menuView: self,
                    uponTapping: element
                )
            } else {
                unhighlightAllElements()
            }

        case .cancelled,
             .failed:
            unhighlightAllElements()

        default:
            break
        }
    }
}
