import SwiftUI

struct AppRootView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "message.fill")
                .font(.system(size: 44))
                .foregroundStyle(VeyraColor.accent)

            Text(AppMetadata.name)
                .font(VeyraTypography.display)

            Text("Built one feature at a time.")
                .font(VeyraTypography.body)
                .foregroundStyle(VeyraColor.textSecondary)
        }
        .foregroundStyle(VeyraColor.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(VeyraSpacing.lg)
        .background(VeyraColor.background)
    }
}

#Preview {
    AppRootView()
}
