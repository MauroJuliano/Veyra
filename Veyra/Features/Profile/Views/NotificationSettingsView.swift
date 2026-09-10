import SwiftUI
import UIKit
@preconcurrency import UserNotifications

struct NotificationSettingsView: View {
    private enum PermissionState {
        case loading
        case unavailable
        case notDetermined
        case denied
        case enabled
    }

    @Environment(\.openURL) private var openURL
    @State private var permissionState: PermissionState = .loading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VeyraSpacing.lg) {
                introduction
                permissionCard
                notificationTypes
            }
            .padding(.horizontal, VeyraSpacing.md)
            .padding(.top, VeyraSpacing.md)
            .padding(.bottom, VeyraSpacing.xl)
        }
        .background(settingsBackground)
        .navigationTitle(Text("Notifications", tableName: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await refreshPermissionState() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshPermissionState() }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
            Text("Stay in the conversation", tableName: "Settings")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(VeyraColor.textPrimary)
            Text("Notification permission is managed by iOS and can be changed at any time in System Settings.", tableName: "Settings")
                .font(VeyraTypography.body)
                .foregroundStyle(VeyraColor.textSecondary)
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: VeyraSpacing.md) {
            HStack(spacing: VeyraSpacing.md) {
                Image(systemName: permissionIcon)
                    .font(.title2)
                    .foregroundStyle(permissionColor)
                    .frame(width: 48, height: 48)
                    .background(permissionColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 15))

                VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
                    Text(permissionTitle, tableName: "Settings")
                        .font(VeyraTypography.bodyEmphasized)
                        .foregroundStyle(VeyraColor.textPrimary)
                    Text(permissionDescription, tableName: "Settings")
                        .font(VeyraTypography.caption)
                        .foregroundStyle(VeyraColor.textSecondary)
                }
            }

            if permissionState == .notDetermined {
                Button(action: requestPermission) {
                    Label {
                        Text("Allow notifications", tableName: "Settings")
                    } icon: {
                        Image(systemName: "bell.badge")
                    }
                    .font(VeyraTypography.bodyEmphasized)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(.white)
                    .background(VeyraColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            } else if permissionState == .denied || permissionState == .enabled {
                Button(action: openSystemSettings) {
                    Label {
                        Text("Open System Settings", tableName: "Settings")
                    } icon: {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(VeyraTypography.bodyEmphasized)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(VeyraColor.accent)
                    .background(VeyraColor.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(VeyraSpacing.md)
        .background { GlassBackground(cornerRadius: 24, tintOpacity: 0.08, glowOpacity: 0.1) }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var notificationTypes: some View {
        VStack(alignment: .leading, spacing: VeyraSpacing.sm) {
            Text("Veyra notifications", tableName: "Settings")
                .font(VeyraTypography.bodyEmphasized)
                .foregroundStyle(VeyraColor.textSecondary)
                .padding(.leading, VeyraSpacing.xs)

            VStack(spacing: 0) {
                notificationRow(
                    icon: "message.fill",
                    title: "New messages",
                    description: "Know when someone sends you a message."
                )
                Divider().padding(.leading, 76).opacity(0.35)
                notificationRow(
                    icon: "phone.fill",
                    title: "Incoming calls",
                    description: "See when another Veyra user is calling."
                )
            }
            .background { GlassBackground(cornerRadius: 24, tintOpacity: 0.07, glowOpacity: 0.08) }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private func notificationRow(icon: String, title: LocalizedStringKey, description: LocalizedStringKey) -> some View {
        HStack(spacing: VeyraSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(VeyraColor.accent)
                .frame(width: 44, height: 44)
                .background(VeyraColor.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
                Text(title, tableName: "Settings").font(VeyraTypography.bodyEmphasized)
                Text(description, tableName: "Settings")
                    .font(VeyraTypography.caption)
                    .foregroundStyle(VeyraColor.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, VeyraSpacing.md)
        .frame(minHeight: 76)
    }

    private var permissionTitle: LocalizedStringKey {
        switch permissionState {
        case .loading: "Checking permission"
        case .unavailable: "Unavailable in this build"
        case .notDetermined: "Notifications are not enabled"
        case .denied: "Notifications are turned off"
        case .enabled: "Notifications are enabled"
        }
    }

    private var permissionDescription: LocalizedStringKey {
        switch permissionState {
        case .loading: "Reading the current iOS notification setting."
        case .unavailable: "Push notifications are disabled for this development build."
        case .notDetermined: "Allow Veyra to notify you about new activity."
        case .denied: "Open System Settings to allow Veyra notifications."
        case .enabled: "iOS can deliver message and call alerts for Veyra."
        }
    }

    private var permissionIcon: String {
        switch permissionState {
        case .loading: "clock"
        case .unavailable: "hammer"
        case .notDetermined: "bell"
        case .denied: "bell.slash.fill"
        case .enabled: "bell.badge.fill"
        }
    }

    private var permissionColor: Color {
        switch permissionState {
        case .enabled: VeyraColor.success
        case .denied: VeyraColor.danger
        default: VeyraColor.accent
        }
    }

    private var settingsBackground: some View {
        ZStack {
            VeyraColor.background
            Circle()
                .fill(VeyraColor.accent.opacity(0.13))
                .frame(width: 300, height: 300)
                .blur(radius: 110)
                .offset(x: 150, y: -280)
        }
        .ignoresSafeArea()
    }

    private func requestPermission() {
        Task {
            await PushNotificationRegistration.requestAuthorization()
            await refreshPermissionState()
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    @MainActor
    private func refreshPermissionState() async {
        guard PushNotificationRegistration.isEnabled else {
            permissionState = .unavailable
            return
        }
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        switch status {
        case .notDetermined: permissionState = .notDetermined
        case .denied: permissionState = .denied
        case .authorized, .provisional, .ephemeral: permissionState = .enabled
        @unknown default: permissionState = .unavailable
        }
    }
}

#Preview("Notifications") {
    NavigationStack { NotificationSettingsView() }
        .preferredColorScheme(.dark)
}
