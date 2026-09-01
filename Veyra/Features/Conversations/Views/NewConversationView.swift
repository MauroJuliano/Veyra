import SwiftUI

struct NewConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    let errorMessage: String?
    let onSubmit: (String) -> Void

    init(errorMessage: String? = nil, onSubmit: @escaping (String) -> Void) {
        self.errorMessage = errorMessage
        self.onSubmit = onSubmit
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: VeyraSpacing.lg) {
                Text("Enter the exact email used by the person on Veyra.")
                    .font(VeyraTypography.body)
                    .foregroundStyle(VeyraColor.textSecondary)

                VeyraTextField(title: "Email", placeholder: "friend@example.com", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .font(VeyraTypography.caption)
                        .foregroundStyle(VeyraColor.danger)
                }

                VeyraPrimaryButton(title: "Start conversation") {
                    onSubmit(email.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                .disabled(!isValidEmail)
                .opacity(isValidEmail ? 1 : 0.55)

                Spacer()
            }
            .padding(VeyraSpacing.lg)
            .background(VeyraColor.background.ignoresSafeArea())
            .navigationTitle("New message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .tint(VeyraColor.accent)
    }

    private var isValidEmail: Bool { email.contains("@") && email.contains(".") }
}

#Preview { NewConversationView(onSubmit: { _ in }) }
