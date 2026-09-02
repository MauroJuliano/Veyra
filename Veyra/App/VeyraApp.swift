import SwiftUI
import UIKit
@preconcurrency import UserNotifications

@main
struct VeyraApp: App {
    @UIApplicationDelegateAdaptor(VeyraAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}

final class VeyraAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: PushNotificationRegistration.tokenKey)
        NotificationCenter.default.post(name: .pushTokenDidChange, object: token)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("APNs registration failed: \(error.localizedDescription)")
        #endif
    }
}

enum PushNotificationRegistration {
    static let tokenKey = "veyra.apnsDeviceToken"
    static var isEnabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "PushNotificationsEnabled") as? Bool == true
    }

    @MainActor
    static func requestAuthorization() async {
        guard isEnabled else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        }
        guard await center.notificationSettings().authorizationStatus == .authorized else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }
}

extension Notification.Name {
    static let pushTokenDidChange = Notification.Name("veyra.pushTokenDidChange")
}

extension View {
    func dismissKeyboardOnTap() -> some View {
        onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
}
