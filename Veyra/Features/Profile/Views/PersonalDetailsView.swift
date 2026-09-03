import SwiftUI
import PhotosUI

struct PersonalDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProfileViewModel

    private var profileAccent: Color { VeyraColor.accent }
    @State private var selectedAvatar: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                profilePhoto

                formulary

                if let message = viewModel.validationMessage {
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(VeyraColor.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                saveButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(VeyraColor.background.ignoresSafeArea())
        .navigationTitle("Personal details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
    }

    private var profilePhoto: some View {
        VStack {
            ZStack(alignment: .bottomTrailing) {
                VeyraAvatar(name: viewModel.profile.displayName, imageURL: viewModel.profile.avatarURL, size: .xLarge)
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(profileAccent)
                    .background(Circle().fill(VeyraColor.surface).padding(2))
            }
            .overlay(alignment: .bottomTrailing) {
                PhotosPicker(selection: $selectedAvatar, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(VeyraColor.accent)
                        .clipShape(Circle())
                }
                .disabled(viewModel.isUploadingAvatar)
                .accessibilityLabel("Change profile photo")
            }

            Text("Tap the photo to update your profile picture")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private extension PersonalDetailsView {
    var formulary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ABOUT YOU")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                profileField(
                    title: "Name",
                    placeholder: "Display name",
                    text: $viewModel.displayName
                )
                .textContentType(.name)

                divider

                profileField(
                    title: "Username",
                    placeholder: "Username",
                    text: $viewModel.username,
                    prefix: "@"
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                divider

                profileField(
                    title: "Email",
                    placeholder: "Email",
                    text: $viewModel.email
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                divider

                bioField
            }
            .padding(.horizontal, 16)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(VeyraColor.surface)
            }
        }
    }

    @ViewBuilder
    func profileField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        prefix: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if let prefix {
                    Text(prefix)
                        .font(.title3)
                        .foregroundStyle(.primary)
                }

                TextField(placeholder, text: text)
                    .font(.title3)
                    .foregroundStyle(.primary)

                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(profileAccent)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(VeyraColor.background.opacity(0.35))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                Color.white.opacity(0.07),
                                lineWidth: 1
                            )
                    }
            }
        }
        .padding(.vertical, 16)
    }

    private var bioField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Bio")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(viewModel.bio.count)/120")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 12) {
                TextField(
                    "Tell people a little about yourself",
                    text: $viewModel.bio,
                    axis: .vertical
                )
                .lineLimit(3...5)
                .font(.body)

                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(profileAccent)
                    .padding(.top, 2)
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(VeyraColor.background.opacity(0.35))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                Color.white.opacity(0.07),
                                lineWidth: 1
                            )
                    }
            }
        }
        .padding(.vertical, 16)
    }

    private var divider: some View {
        Divider()
            .overlay(Color.white.opacity(0.08))
    }

    private var saveButton: some View {
        Button {
            Task {
                if await viewModel.save() {
                    dismiss()
                }
            }
        } label: {
            Group {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Text("Save changes")
                        .font(.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(profileAccent.opacity(0.75))
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSaving)
    }
}

#Preview {
    NavigationStack {
        PersonalDetailsView(viewModel: ProfileViewModel(store: InMemoryProfileStore()))
    }
    .preferredColorScheme(.dark)
}
