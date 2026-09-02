import SwiftUI
import PhotosUI

struct ProfileView: View {
    private enum Route: String, Hashable {
        case personalDetails = "Personal details"
        case privacy = "Privacy"
        case notifications = "Notifications"
        case help = "Help & Support"
        case language = "Language"

        var icon: String {
            switch self {
            case .personalDetails: "person"
            case .privacy: "lock"
            case .notifications: "bell"
            case .help: "questionmark.circle"
            case .language: "globe"
            }
        }
    }

    private struct SettingsItem: Identifiable {
        let route: Route
        let subtitle: String
        var id: Route { route }
    }

    @State private var confirmsLogout = false
    @State private var viewModel: ProfileViewModel
    @State private var selectedAvatar: PhotosPickerItem?
    let onLogout: () -> Void

    init(viewModel: ProfileViewModel = ProfileViewModel(), onLogout: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onLogout = onLogout
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: VeyraSpacing.lg) {
                    header
                    profileCard
                    settingsSection(title: "Account", items: accountItems)
                    settingsSection(title: "Support & Preferences", items: supportItems)
                    logoutButton
                }
                .padding(.horizontal, VeyraSpacing.md)
                .padding(.bottom, VeyraSpacing.xl)
            }
            .background(profileBackground)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                if route == .personalDetails {
                    PersonalDetailsView(viewModel: viewModel)
                } else {
                    ProfileDetailPlaceholder(route: route.rawValue, systemImage: route.icon)
                }
            }
            .confirmationDialog("Log out of Veyra?", isPresented: $confirmsLogout, titleVisibility: .visible) {
                Button("Log out", role: .destructive, action: onLogout)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You will return to the login screen.")
            }
        }
        .preferredColorScheme(.dark)
        .task { await viewModel.loadRemoteProfile() }
        .onChange(of: selectedAvatar) { _, item in updateAvatar(from: item) }
    }

    private var header: some View {
        HStack {
            Text("Profile")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(VeyraColor.textPrimary)
            Spacer()
        }
        .padding(.top, VeyraSpacing.md)
    }

    private var profileCard: some View {
        HStack(spacing: VeyraSpacing.md) {
            ZStack(alignment: .bottomTrailing) {
                VeyraAvatar(name: viewModel.profile.displayName, imageURL: viewModel.profile.avatarURL, size: .large)
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

            VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
                Text(viewModel.profile.displayName)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                Label("Verified member", systemImage: "checkmark.seal.fill")
                    .font(VeyraTypography.caption.weight(.medium))
                    .foregroundStyle(profileAccent)
                Text(viewModel.profile.formattedUsername)
                    .font(VeyraTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: VeyraSpacing.xs)

            NavigationLink(value: Route.personalDetails) {
                Label("Edit", systemImage: "pencil")
                    .font(VeyraTypography.caption.weight(.semibold))
                    .foregroundStyle(profileAccent)
                    .padding(.horizontal, VeyraSpacing.md)
                    .frame(height: 40)
                    .background(profileAccent.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(VeyraSpacing.md)
        .background { GlassBackground(cornerRadius: 28, tintOpacity: 0.1, glowOpacity: 0.1) }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func settingsSection(title: String, items: [SettingsItem]) -> some View {
        VStack(alignment: .leading, spacing: VeyraSpacing.sm) {
            Text(title)
                .font(VeyraTypography.bodyEmphasized)
                .foregroundStyle(VeyraColor.textSecondary)
                .padding(.leading, VeyraSpacing.xs)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(value: item.route) { settingsRow(item) }
                        .buttonStyle(.plain)
                    if index < items.count - 1 {
                        Divider().padding(.leading, 76).opacity(0.35)
                    }
                }
            }
            .background { GlassBackground(cornerRadius: 24, tintOpacity: 0.07, glowOpacity: 0.08) }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private func settingsRow(_ item: SettingsItem) -> some View {
        HStack(spacing: VeyraSpacing.md) {
            Image(systemName: item.route.icon)
                .font(.system(size: 20))
                .foregroundStyle(profileAccent)
                .frame(width: 44, height: 44)
                .background(profileAccent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
                Text(item.route.rawValue).font(VeyraTypography.bodyEmphasized)
                Text(item.subtitle).font(VeyraTypography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(VeyraColor.textSecondary)
        }
        .padding(.horizontal, VeyraSpacing.md)
        .frame(minHeight: 76)
        .contentShape(Rectangle())
    }

    private var logoutButton: some View {
        Button { confirmsLogout = true } label: {
            HStack(spacing: VeyraSpacing.md) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(Color.red.opacity(0.75))
                    .frame(width: 44, height: 44)
                    .background(Color.red.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Text("Log out").font(VeyraTypography.bodyEmphasized).foregroundStyle(Color.red.opacity(0.8))
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(VeyraColor.textSecondary)
            }
            .padding(.horizontal, VeyraSpacing.md)
            .frame(height: 70)
            .background { GlassBackground(cornerRadius: 24, tintOpacity: 0.06, glowOpacity: 0.06) }
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    private var profileAccent: Color { VeyraColor.accent }

    private var profileBackground: some View {
        ZStack {
            LinearGradient(
                colors: [VeyraColor.background, VeyraColor.accentMuted.opacity(0.7), VeyraColor.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(VeyraColor.accent.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: 150, y: -260)
        }
        .ignoresSafeArea()
    }

    private var accountItems: [SettingsItem] {
        [
            SettingsItem(route: .personalDetails, subtitle: "Edit your info and preferences"),
            SettingsItem(route: .privacy, subtitle: "Control who can see you"),
            SettingsItem(route: .notifications, subtitle: "Manage your alerts and sounds")
        ]
    }

    private var supportItems: [SettingsItem] {
        [
            SettingsItem(route: .help, subtitle: "Get help or contact us"),
            SettingsItem(route: .language, subtitle: "Choose your preferred language")
        ]
    }

    private func updateAvatar(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await viewModel.updateAvatar(data: data)
            }
            selectedAvatar = nil
        }
    }
}

private struct ProfileDetailPlaceholder: View {
    let route: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(route, systemImage: systemImage, description: Text("This setting will be implemented in a focused pull request."))
            .navigationTitle(route)
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileView(onLogout: {})
}
