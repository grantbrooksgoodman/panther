//
//  ChatInfoContentPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import Redux

public struct ChatInfoContentPageView: View {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatInfoPageView

    // MARK: - Properties

    @ObservedObject private var viewModel: ViewModel<ChatInfoPageReducer>

    // MARK: - Bindings

    private var imagePickerSheetBinding: Binding<Bool> {
        viewModel.binding(
            for: \.isPresentingImagePickerSheet,
            sendAction: { .isPresentingImagePickerSheetChanged($0) }
        )
    }

    // MARK: - Init

    public init(_ viewModel: ViewModel<ChatInfoPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        ThemedView {
            NavigationView {
                contentView
                    .id(viewModel.viewID)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.listViewBackground)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        doneToolbarButton
                    }
            }
            .accentColor(Color.accent)
            .toolbarBackground(Color.navigationBarBackground, for: .navigationBar)
            .sheet(isPresented: imagePickerSheetBinding) {
                ImagePickerView(.photoLibrary) { image in
                    viewModel.send(.selectedImageChanged(image))
                } onDismiss: {
                    viewModel.send(.isPresentingImagePickerSheetChanged(false))
                }
            }
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        if let cnContactContainer = viewModel.singleCNContactContainer {
            CNContactView(
                cnContactContainer.cnContact,
                isUnknown: cnContactContainer.isUnknown
            )
            .offset(y: Floats.singleCNContactViewYOffset)
            .header(rightItem: doneHeaderItem, isThemed: true)
            .toolbar(.hidden)
        } else {
            VStack {
                AvatarImageView(
                    viewModel.avatarImage,
                    badgeCount: -1,
                    size: .init(
                        width: Floats.largeAvatarImageViewSizeWidth,
                        height: Floats.largeAvatarImageViewSizeHeight
                    )
                )
                .padding(.bottom, 1)
                .padding(.top, Floats.avatarImageViewTopPadding)
                .padding(.horizontal, Floats.avatarImageViewHorizontalPadding)

                Text(viewModel.chatTitleLabelText)
                    .font(.sanFrancisco(.bold, size: Floats.chatTitleLabelFontSize))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 1)
                    .padding(.horizontal, Floats.chatTitleLabelHorizontalPadding)

                Button {
                    viewModel.send(.changeMetadataButtonTapped)
                } label: {
                    Text(viewModel.strings.value(for: .changeMetadataButtonText))
                        .font(.sanFrancisco(size: Floats.changeMetadataButtonLabelFontSize))
                        .foregroundStyle(viewModel.isChangeMetadataButtonEnabled ? Color.accent : .disabled)
                }
                .disabled(!viewModel.isChangeMetadataButtonEnabled)
                .padding(.bottom, 1)
                .padding(.horizontal, Floats.changeMetadataButtonHorizontalPadding)

                listView

                Spacer()
            }
        }
    }

    // MARK: - Chat Info Cell

    private var chatInfoCell: some View {
        Button {
            viewModel.send(.chatInfoCellTapped)
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading) {
                    Text(viewModel.chatInfoCellTitleLabelText)
                        .font(.sanFrancisco(.semibold, size: Floats.chatInfoCellTitleLabelFontSize))
                        .padding(.bottom, 1)

                    Text(viewModel.chatInfoCellSubtitleLabelText)
                        .lineLimit(1)
                        .font(.sanFrancisco(size: Floats.chatInfoCellSubtitleLabelFontSize))
                        .foregroundStyle(Color.subtitleText)
                }

                Spacer()

                Image(systemName: viewModel.chatInfoCellImageSystemName)
                    .foregroundStyle(Color.subtitleText)
            }
        }
        .foregroundStyle(Color.titleText)
    }

    // MARK: - Done Header/Toolbar Buttons

    private var doneHeaderItem: HeaderView.PeripheralButtonType {
        .text(
            .init(text: .init(viewModel.doneButtonText)) {
                viewModel.send(.doneHeaderItemTapped)
            }
        )
    }

    private var doneToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.send(.doneToolbarButtonTapped)
            } label: {
                Text(viewModel.doneButtonText)
                    .bold()
                    .foregroundStyle(Color.accent)
            }
        }
    }

    // MARK: - List View

    private var listView: some View {
        List {
            ForEach(-1 ..< viewModel.visibleParticipants.count, id: \.self) { index in
                if index == -1 {
                    chatInfoCell
                } else if let participant = viewModel.visibleParticipants.itemAt(index),
                          let cnContactContainer = participant.cnContactContainer {
                    NavigationLink(
                        destination:
                        CNContactView(
                            cnContactContainer.cnContact,
                            isUnknown: cnContactContainer.isUnknown
                        )
                    ) {
                        participantView(participant)
                    }
                }
            }
        }
        .animation(.default, value: viewModel.visibleParticipants)
        .offset(y: Floats.listViewYOffset)
    }

    // MARK: - Participant View

    private func participantView(_ participant: ChatParticipant) -> some View {
        HStack(alignment: .center) {
            AvatarImageView(
                participant.thumbnailImage,
                size: .init(
                    width: Floats.smallAvatarImageViewSizeWidth,
                    height: Floats.smallAvatarImageViewSizeHeight
                )
            )
            .padding(.trailing, Floats.smallAvatarImageViewTrailingPadding)

            Text(participant.displayName)
                .font(.sanFrancisco(.semibold, size: Floats.participantViewDisplayNameLabelFontSize))

            if let firstUser = participant.contactPair?.firstUser {
                UserInfoBadgeView(firstUser)
            }
        }
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.ChatInfoPageViewStringKey) -> String {
        (first(where: { $0.key == .chatInfoPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
