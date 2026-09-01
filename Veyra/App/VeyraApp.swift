import SwiftUI
import UIKit

@main
struct VeyraApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
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
