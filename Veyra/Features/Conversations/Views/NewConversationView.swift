import SwiftUI

struct NewConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    let onSubmit: (String) async -> String?

    init(onSubmit: @escaping (String) async -> String?) {
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

                VeyraPrimaryButton(title: isLoading ? "Starting…" : "Start conversation") {
                    Task {
                        isLoading = true
                        errorMessage = await onSubmit(email.trimmingCharacters(in: .whitespacesAndNewlines))
                        isLoading = false
                    }
                }
                .disabled(!isValidEmail || isLoading)
                .opacity(isValidEmail && !isLoading ? 1 : 0.55)

                Spacer()
            }
            .padding(VeyraSpacing.lg)
            .contentShape(Rectangle())
            .dismissKeyboardOnTap()
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

#Preview { NewConversationView(onSubmit: { _ in nil }) }
