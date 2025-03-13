//
//  ContextMenuViewController.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

final class ContextMenuViewController: UIViewController {
    // MARK: - Properties

    // UIView
    let accessoryView: UIView?
    let previewRendering: UIView

    // Other
    let baseFrameInScreen: CGRect
    let interaction: ContextMenuInteractor.Interaction
    let style: ContextMenuStyle

    weak var delegate: ContextMenuViewControllerDelegate?

    var constraintsAlteringPreviewPosition = [NSLayoutConstraint]()
    var menuView: MenuView?
    var targetedPreview: UITargetedPreview?

    private let menuConfiguration: ContextMenuConfiguration?

    // MARK: - Computed Properties

    var animatableAccessoryView: ContextMenuAnimatable? { accessoryView as? ContextMenuAnimatable }

    lazy var backgroundBlur: UIVisualEffectView = {
        let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: style.backgroundBlurStyle))
        visualEffectView.alpha = 0
        visualEffectView.isUserInteractionEnabled = true
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false

        let tapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(onTouchUpInsideBackground)
        )
        visualEffectView.addGestureRecognizer(tapGestureRecognizer)
        return visualEffectView
    }()

    private lazy var previewTransformedBoundingView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Init

    init(
        interaction: ContextMenuInteractor.Interaction,
        view: UIView,
        targetedPreview: UITargetedPreview,
        baseFrameInScreen: CGRect,
        delegate: ContextMenuViewControllerDelegate?
    ) {
        let configuration = interaction.menuConfigurationProvider(view)

        self.interaction = interaction
        menuConfiguration = configuration
        self.targetedPreview = targetedPreview
        previewRendering = targetedPreview.view.snapshotView(afterScreenUpdates: false) ?? UIView()
        self.baseFrameInScreen = baseFrameInScreen
        accessoryView = configuration?.accessoryView
        style = interaction.style
        self.delegate = delegate

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Did Load

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = style.backgroundColor

        let alignmentToPreview = menuAndAccessoryViewAlignment()

        let backgroundConstraints = setupBackgroundBlur()
        // Preview must be kept above all in case it's too tall to fit in screen in which
        // case both accessoryView & menu will overlap
        let previewConstraints = setupPreview()
        let accessoryViewConstraints = setupAccessoryViewIfNeeded(alignment: alignmentToPreview)
        let menuConstraints = setupMenuViewIfNeeded(alignment: alignmentToPreview)

        // Immediately apply fixed constraints to setup initial state of view
        NSLayoutConstraint.activate(
            backgroundConstraints.fixed
                + accessoryViewConstraints.fixed
                + previewConstraints.fixed
                + menuConstraints.fixed
        )

        // Consolidate animatable constraints, for final position to be set
        // once enabled.
        constraintsAlteringPreviewPosition.append(contentsOf:
            backgroundConstraints.animatable
                + accessoryViewConstraints.animatable
                + previewConstraints.animatable
                + menuConstraints.animatable
        )

        view.layoutIfNeeded()
    }

    // MARK: - Auxiliary

    private func setupAccessoryViewIfNeeded(
        alignment: Alignment
    ) -> FixedAndAnimatableConstraints {
        guard let accessoryView else { return .empty }

        view.addSubview(accessoryView)
        accessoryView.translatesAutoresizingMaskIntoConstraints = false

        return FixedAndAnimatableConstraints(
            fixed: [
                accessoryView.bottomAnchor.constraint(
                    equalTo: previewTransformedBoundingView.topAnchor, constant: -style.preview.topMargin
                ).priority(.required - 1),
                alignment == .leading ?
                    accessoryView.leadingAnchor.constraint(equalTo: previewTransformedBoundingView.leadingAnchor).priority(.defaultHigh)
                    : accessoryView.trailingAnchor.constraint(equalTo: previewTransformedBoundingView.trailingAnchor).priority(.defaultHigh),
            ],
            animatable: NSLayoutConstraint.keeping(view: accessoryView, insideFrameOf: view)
        )
    }

    private func setupBackgroundBlur() -> FixedAndAnimatableConstraints {
        view.addSubview(backgroundBlur)
        return .init(
            fixed: [
                backgroundBlur.topAnchor.constraint(equalTo: view.topAnchor),
                backgroundBlur.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                backgroundBlur.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                backgroundBlur.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ],
            animatable: []
        )
    }

    private func setupMenuViewIfNeeded(
        alignment: Alignment
    ) -> FixedAndAnimatableConstraints {
        guard let menuConfiguration, !menuConfiguration.menu.children.isEmpty else { return .empty }

        let menuView = MenuView(
            menu: menuConfiguration.menu,
            anchorPointAlignment: alignment,
            style: style.menu,
            delegate: self
        )
        self.menuView = menuView
        menuView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menuView)

        return FixedAndAnimatableConstraints(
            fixed: [
                menuView.topAnchor.constraint(
                    equalTo: previewTransformedBoundingView.bottomAnchor, constant: style.preview.bottomMargin
                ),
                alignment == .leading ?
                    menuView.leadingAnchor.constraint(equalTo: previewTransformedBoundingView.leadingAnchor).priority(.defaultHigh)
                    : menuView.trailingAnchor.constraint(equalTo: previewTransformedBoundingView.trailingAnchor).priority(.defaultHigh),
            ],
            animatable: NSLayoutConstraint.keeping(view: menuView, insideFrameOf: view)
        )
    }

    private func setupPreview() -> FixedAndAnimatableConstraints {
        /*
         Quick reminder:
         - targetedPreview: Native UITargetedPreview, aka parameters of view to parameters
         - targetedPreview.view: Original view
         - previewRendering: The view used as preview. It's a rendering (aka: a snapshot of original view)
         - previewTransformedBoundingView: A view used as container for `previewRendering`, whose frame
            matches the untransformed position of the rendering
         */
        previewRendering.translatesAutoresizingMaskIntoConstraints = false

        previewTransformedBoundingView.addSubview(previewRendering)
        view.addSubview(previewTransformedBoundingView)
        targetedPreview?.view.alpha = 0

        return FixedAndAnimatableConstraints(
            fixed: [
                previewRendering.leadingAnchor.constraint(
                    equalTo: view.leadingAnchor, constant: baseFrameInScreen.minX
                ).priority(.defaultHigh),
                previewRendering.topAnchor.constraint(
                    equalTo: view.topAnchor,
                    constant: baseFrameInScreen.minY
                ).priority(.defaultHigh),
                previewRendering.widthAnchor.constraint(equalToConstant: baseFrameInScreen.width),
                previewRendering.heightAnchor.constraint(equalToConstant: baseFrameInScreen.height),
                previewTransformedBoundingView.widthAnchor.constraint(
                    equalToConstant: baseFrameInScreen.width * style.preview.transform.a
                ),
                previewTransformedBoundingView.heightAnchor.constraint(
                    equalToConstant: baseFrameInScreen.height * style.preview.transform.d
                ),
                previewTransformedBoundingView.centerXAnchor.constraint(equalTo: previewRendering.centerXAnchor),
                previewTransformedBoundingView.centerYAnchor.constraint(equalTo: previewRendering.centerYAnchor),
            ],
            animatable: [previewTransformedBoundingView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor)]
        )
    }
}
