import SwiftUI

struct AppRootView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "message.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            Text(AppMetadata.name)
                .font(.largeTitle.bold())

            Text("Built one feature at a time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    AppRootView()
}
